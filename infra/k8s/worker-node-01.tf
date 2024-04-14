# Source the Cloud Init userdata Config file
data "template_file" "cloud_init_worker_node_01_userdata" {
  template = file("${path.module}/cloud-inits/userdata.yml.tftpl")

  vars = {
    hostname        = local.worker_node_01.hostname
    user_name       = var.userdata.user_name
    hashed_password = var.userdata.hashed_password
    github_id       = var.userdata.github_id
  }
}

# Source the Cloud Init network Config file
data "template_file" "cloud_init_worker_node_01_network" {
  template = file("${path.module}/cloud-inits/network.yml.tftpl")

  vars = {
    ipv4_address          = local.worker_node_01.ipv4_address
    ipv4_prefix           = local.worker_node_01.ipv4_prefix
    ipv4_default_gateway  = local.worker_node_01.ipv4_default_gateway
    ipv6_address_token    = local.worker_node_01.ipv6_address_token
    nas_interface_address = local.worker_node_01.nas_interface_address
    nas_network_address   = local.worker_node_01.nas_network_address
    nas_network_gateway   = local.worker_node_01.nas_network_gateway
  }
}

# Create a local copy of the file, to transfer to Proxmox
resource "local_file" "cloud_init_worker_node_01_userdata" {
  content  = data.template_file.cloud_init_worker_node_01_userdata.rendered
  filename = "${path.module}/.tmp/cloud_init_worker_node_01_userdata.yml"
}

# Create a local copy of the file, to transfer to Proxmox
resource "local_file" "cloud_init_worker_node_01_network" {
  content  = data.template_file.cloud_init_worker_node_01_network.rendered
  filename = "${path.module}/.tmp/cloud_init_worker_node_01_network.yml"
}

# Transfer the cloud-init userdata file to the Proxmox Host
resource "proxmox_virtual_environment_file" "cloud_init_worker_node_01_userdata" {
  content_type = "snippets"
  datastore_id = "local"
  overwrite    = true
  node_name    = local.worker_node_01.proxmox_node

  source_file {
    path      = local_file.cloud_init_worker_node_01_userdata.filename
    file_name = "cloud_init_worker_node_01_userdata.yml"
  }
}

# Transfer the cloud-init network file to the Proxmox Host
resource "proxmox_virtual_environment_file" "cloud_init_worker_node_01_network" {
  content_type = "snippets"
  datastore_id = "local"
  overwrite    = true
  node_name    = local.worker_node_01.proxmox_node

  source_file {
    path      = local_file.cloud_init_worker_node_01_network.filename
    file_name = "cloud_init_worker_node_01_network.yml"
  }
}

resource "proxmox_virtual_environment_vm" "vm_worker_node_01" {
  # Wait for the cloud-config file to exist
  depends_on = [
    proxmox_virtual_environment_file.cloud_init_worker_node_01_userdata,
    proxmox_virtual_environment_file.cloud_init_worker_node_01_network
  ]

  vm_id     = local.worker_node_01.vmid
  name      = local.worker_node_01.hostname
  node_name = local.worker_node_01.proxmox_node

  started = true
  on_boot = local.worker_node_01.onboot

  bios    = "seabios"
  machine = "pc"

  startup {
    order = "3"
  }

  agent {
    enabled = true
  }

  clone {
    vm_id = local.worker_node_01.template_vmid
    full  = true
  }

  operating_system {
    type = "l26"
  }

  initialization {
    datastore_id         = "local-zfs"
    interface            = "ide2"
    user_data_file_id    = proxmox_virtual_environment_file.cloud_init_worker_node_01_userdata.id
    network_data_file_id = proxmox_virtual_environment_file.cloud_init_worker_node_01_network.id
  }

  memory {
    dedicated = local.worker_node_01.memory
    floating  = local.worker_node_01.memory
  }
  cpu {
    cores = local.worker_node_01.cores
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

  hostpci {
    # Intel Corporation CoffeeLake-S GT2 [UHD Graphics 630]
    device = "hostpci0"
    id     = "0000:00:02"
    mdev   = "i915-GVTg_V5_4"
  }

  hostpci {
    # Intel Corporation 82599 10 Gigabit Network Connection
    device = "hostpci1"
    id     = "0000:02:00"
  }

  hostpci {
    # Digital Devices GmbH Device 000a
    device = "hostpci2"
    id     = "0000:06:00"
  }

  usb {
    # Advanced Card Systems, Ltd ACR39U
    host = "072f:b100"
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
resource "null_resource" "vm_worker_node_01_reboot" {
  depends_on = [proxmox_virtual_environment_vm.vm_worker_node_01]

  provisioner "remote-exec" {
    connection {
      type  = "ssh"
      user  = var.userdata.user_name
      agent = true
      host  = local.worker_node_01.ipv4_address
    }
    inline = [
      "sudo cloud-init status --wait",
      "sudo shutdown -r +0"
    ]
  }
}
