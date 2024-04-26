# Source the Cloud Init userdata Config file
data "template_file" "cloud_init_vpn_server_userdata" {
  template = file("${path.module}/cloud-inits/userdata.yml.tftpl")

  vars = {
    hostname        = local.vpn_server.hostname
    user_name       = var.userdata.user_name
    hashed_password = var.userdata.hashed_password
    github_id       = var.userdata.github_id
  }
}

# Source the Cloud Init network Config file
data "template_file" "cloud_init_vpn_server_network" {
  template = file("${path.module}/cloud-inits/network.yml.tftpl")

  vars = {
    ipv4_address          = local.vpn_server.ipv4_address
    ipv4_prefix           = local.vpn_server.ipv4_prefix
    ipv4_default_gateway  = local.vpn_server.ipv4_default_gateway
    ipv6_address_token    = local.vpn_server.ipv6_address_token
    nas_interface_address = ""
  }
}

# Create a local copy of the file, to transfer to Proxmox
resource "local_file" "cloud_init_vpn_server_userdata" {
  content  = data.template_file.cloud_init_vpn_server_userdata.rendered
  filename = "${path.module}/.tmp/cloud_init_vpn_server_userdata.yml"
}

# Create a local copy of the file, to transfer to Proxmox
resource "local_file" "cloud_init_vpn_server_network" {
  content  = data.template_file.cloud_init_vpn_server_network.rendered
  filename = "${path.module}/.tmp/cloud_init_vpn_server_network.yml"
}

# Transfer the cloud-init userdata file to the Proxmox Host
resource "proxmox_virtual_environment_file" "cloud_init_vpn_server_userdata" {
  content_type = "snippets"
  datastore_id = "local"
  overwrite    = true
  node_name    = local.vpn_server.proxmox_node

  source_file {
    path      = local_file.cloud_init_vpn_server_userdata.filename
    file_name = "cloud_init_vpn_server_userdata.yml"
  }
}

# Transfer the cloud-init network file to the Proxmox Host
resource "proxmox_virtual_environment_file" "cloud_init_vpn_server_network" {
  content_type = "snippets"
  datastore_id = "local"
  overwrite    = true
  node_name    = local.vpn_server.proxmox_node

  source_file {
    path      = local_file.cloud_init_vpn_server_network.filename
    file_name = "cloud_init_vpn_server_network.yml"
  }
}

resource "proxmox_virtual_environment_vm" "vm_vpn_server" {
  # Wait for the cloud-config file to exist
  depends_on = [
    proxmox_virtual_environment_file.cloud_init_vpn_server_userdata,
    proxmox_virtual_environment_file.cloud_init_vpn_server_network
  ]

  vm_id     = local.vpn_server.vmid
  name      = local.vpn_server.hostname
  node_name = local.vpn_server.proxmox_node

  started = true
  on_boot = local.vpn_server.onboot

  bios    = "seabios"
  machine = "pc"

  startup {
    order = "3"
  }

  agent {
    enabled = true
  }

  clone {
    vm_id = local.vpn_server.template_vmid
    full  = true
  }

  operating_system {
    type = "l26"
  }

  initialization {
    datastore_id         = "local-zfs"
    interface            = "ide2"
    user_data_file_id    = proxmox_virtual_environment_file.cloud_init_vpn_server_userdata.id
    network_data_file_id = proxmox_virtual_environment_file.cloud_init_vpn_server_network.id
  }

  memory {
    dedicated = local.vpn_server.memory
    floating  = local.vpn_server.memory
  }
  cpu {
    cores = local.vpn_server.cores
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
    size         = 128
    ssd          = true
  }

  network_device {
    model  = "virtio"
    bridge = "vmbr0"
  }

  network_device {
    model  = "virtio"
    bridge = "vmbr1"
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
resource "null_resource" "vm_vpn_server_reboot" {
  depends_on = [proxmox_virtual_environment_vm.vm_vpn_server]

  provisioner "remote-exec" {
    connection {
      type  = "ssh"
      user  = var.userdata.user_name
      agent = true
      host  = local.vpn_server.ipv4_address
    }
    inline = [
      "sudo cloud-init status --wait",
      "sudo shutdown -r +0"
    ]
  }
}
