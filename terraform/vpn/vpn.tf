# Source the Cloud Init userdata Config file
data "template_file" "cloud_init_vpn_userdata" {
  template = file("${path.module}/cloud-inits/userdata.yml.tftpl")

  vars = {
    hostname        = local.vpn.hostname
    user_name       = var.userdata.user_name
    hashed_password = var.userdata.hashed_password
    github_id       = var.userdata.github_id

    wg_if_ip              = local.vpn.wg_if_ip
    wg_peer_if_ip         = local.vpn.wg_peer_if_ip
    wg_peer_private_ip    = data.terraform_remote_state.aws.outputs.s2s_vpn_private_ipv4
    wg_peer_pubkey        = data.terraform_remote_state.aws.outputs.s2s_vpn_wg_pubkey
    wg_peer_ipv6_endpoint = data.terraform_remote_state.aws.outputs.s2s_vpn_public_ipv6
  }
}

# Source the Cloud Init network Config file
data "template_file" "cloud_init_vpn_network" {
  template = file("${path.module}/cloud-inits/network.yml.tftpl")

  vars = {
    ipv4_address         = local.vpn.ipv4_address
    ipv4_prefix          = local.vpn.ipv4_prefix
    ipv4_default_gateway = local.vpn.ipv4_default_gateway
    ipv6_address_token   = local.vpn.ipv6_address_token
  }
}

# Create a local copy of the file, to transfer to Proxmox
resource "local_file" "cloud_init_vpn_userdata" {
  content  = data.template_file.cloud_init_vpn_userdata.rendered
  filename = "${path.module}/.tmp/cloud_init_vpn_userdata.yml"
}

# Create a local copy of the file, to transfer to Proxmox
resource "local_file" "cloud_init_vpn_network" {
  content  = data.template_file.cloud_init_vpn_network.rendered
  filename = "${path.module}/.tmp/cloud_init_vpn_network.yml"
}

# Transfer the cloud-init userdata file to the Proxmox Host
resource "proxmox_virtual_environment_file" "cloud_init_vpn_userdata" {
  content_type = "snippets"
  datastore_id = "local"
  overwrite    = true
  node_name    = local.vpn.proxmox_node

  source_file {
    path      = local_file.cloud_init_vpn_userdata.filename
    file_name = "cloud_init_vpn_userdata.yml"
  }
}

# Transfer the cloud-init network file to the Proxmox Host
resource "proxmox_virtual_environment_file" "cloud_init_vpn_network" {
  content_type = "snippets"
  datastore_id = "local"
  overwrite    = true
  node_name    = local.vpn.proxmox_node

  source_file {
    path      = local_file.cloud_init_vpn_network.filename
    file_name = "cloud_init_vpn_network.yml"
  }
}


resource "proxmox_virtual_environment_vm" "vm_vpn" {
  # Wait for the cloud-config file to exist
  depends_on = [
    proxmox_virtual_environment_file.cloud_init_vpn_userdata,
    proxmox_virtual_environment_file.cloud_init_vpn_network
  ]

  vm_id     = local.vpn.vmid
  name      = local.vpn.hostname
  node_name = local.vpn.proxmox_node

  started = true
  on_boot = local.vpn.onboot

  bios    = "seabios"
  machine = "pc"

  agent {
    enabled = true
  }

  clone {
    vm_id = local.vpn.template_vmid
    full  = true
  }

  operating_system {
    type = "l26"
  }

  initialization {
    datastore_id         = "local-zfs"
    interface            = "ide2"
    user_data_file_id    = proxmox_virtual_environment_file.cloud_init_vpn_userdata.id
    network_data_file_id = proxmox_virtual_environment_file.cloud_init_vpn_network.id
  }

  memory {
    dedicated = local.vpn.memory
    floating  = local.vpn.memory
  }

  cpu {
    cores = local.vpn.cores
    type  = "host"
    units = 1024
  }

  boot_order = [
    "scsi0"
  ]

  scsi_hardware = "virtio-scsi-pci"

  disk {
    datastore_id = "local-zfs"
    file_format  = "raw"
    interface    = "scsi0"
    size         = local.vpn.disk_size
    ssd          = true
  }

  network_device {
    model  = "virtio"
    bridge = "vmbr0"
  }

  # Ignore changes
  lifecycle {
    ignore_changes = [
      started,
      vga
    ]
  }
}

# Wait for cloud-init completed
resource "terraform_data" "wait_for_clout_init" {
  depends_on = [proxmox_virtual_environment_vm.vm_vpn]

  provisioner "remote-exec" {
    connection {
      type  = "ssh"
      user  = var.userdata.user_name
      agent = true
      host  = local.vpn.ipv4_address
    }
    inline = ["sudo cloud-init status --wait || true"]
  }
}

data "external" "wg_pubkey" {
  depends_on = [terraform_data.wait_for_clout_init]

  program = ["bash", "${path.module}/scripts/read_file.sh"]

  query = {
    host = local.vpn.ipv4_address
    user = var.userdata.user_name
    key  = "~/.ssh/gpg.pub"
    path = "/etc/wireguard/public.key"
  }
}

data "external" "wg_pskey" {
  depends_on = [terraform_data.wait_for_clout_init]

  program = ["bash", "${path.module}/scripts/read_file.sh"]

  query = {
    host = local.vpn.ipv4_address
    user = var.userdata.user_name
    key  = "~/.ssh/gpg.pub"
    path = "/etc/wireguard/preshared.key"
  }
}

resource "terraform_data" "reboot" {
  depends_on = [data.external.wg_pubkey]

  provisioner "remote-exec" {
    connection {
      type  = "ssh"
      user  = var.userdata.user_name
      agent = true
      host  = local.vpn.ipv4_address
    }
    inline = ["sudo shutdown -r +0"]
  }
}

resource "terraform_data" "add_peer_to_server" {
  depends_on = [data.external.wg_pubkey]
  triggers_replace = [
    data.external.wg_pubkey.result.content
  ]

  provisioner "remote-exec" {
    connection {
      type  = "ssh"
      user  = "ubuntu"
      agent = true
      host  = data.terraform_remote_state.aws.outputs.s2s_vpn_public_ipv4
    }
    inline = [
      <<EOF
cat << EOS | sudo tee -a /etc/wireguard/wg0.conf
[Peer]
PublicKey = ${data.external.wg_pubkey.result.content}
AllowedIPs = ${local.vpn.wg_if_ip}/32,172.16.254.0/24
PresharedKey = ${data.external.wg_pskey.result.content}
PersistentKeepalive = 25

EOS
sudo service wg-quick@wg0 restart
      EOF
    ]
  }
}
