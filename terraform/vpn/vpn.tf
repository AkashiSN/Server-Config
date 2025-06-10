# Source the Cloud Init userdata Config file
data "template_file" "cloud_init_vpn_userdata" {
  template = file("${path.module}/cloud-inits/userdata.yml.tftpl")

  vars = {
    hostname        = local.vpn.hostname
    user_name       = var.userdata.user_name
    hashed_password = var.userdata.hashed_password
    github_id       = var.userdata.github_id
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
    size         = 64
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

# Wait for cloud-init completed, reboot vm
resource "null_resource" "vm_vpn_reboot" {
  depends_on = [proxmox_virtual_environment_vm.vm_vpn]

  provisioner "remote-exec" {
    connection {
      type  = "ssh"
      user  = var.userdata.user_name
      agent = true
      host  = local.vpn.ipv4_address
    }
    inline = [
      "sudo cloud-init status --wait",
      "sudo shutdown -r +0"
    ]
  }
}
