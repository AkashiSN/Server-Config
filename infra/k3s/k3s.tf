# Source the Cloud Init userdata Config file
data "template_file" "cloud_init_k3s_userdata" {
  template = file("${path.module}/cloud-inits/userdata.yml.tftpl")

  vars = {
    hostname        = local.k3s.hostname
    user_name       = var.userdata.user_name
    hashed_password = var.userdata.hashed_password
    github_id       = var.userdata.github_id
  }
}

# Source the Cloud Init network Config file
data "template_file" "cloud_init_k3s_network" {
  template = file("${path.module}/cloud-inits/network.yml.tftpl")

  vars = {
    ipv4_address         = local.k3s.ipv4_address
    ipv4_prefix          = local.k3s.ipv4_prefix
    ipv4_default_gateway = local.k3s.ipv4_default_gateway
  }
}

# Create a local copy of the file, to transfer to Proxmox
resource "local_file" "cloud_init_k3s_userdata" {
  content  = data.template_file.cloud_init_k3s_userdata.rendered
  filename = "${path.module}/.tmp/cloud_init_k3s_userdata.yml"
}

# Create a local copy of the file, to transfer to Proxmox
resource "local_file" "cloud_init_k3s_network" {
  content  = data.template_file.cloud_init_k3s_network.rendered
  filename = "${path.module}/.tmp/cloud_init_k3s_network.yml"
}

# Transfer the cloud-init userdata file to the Proxmox Host
resource "proxmox_virtual_environment_file" "cloud_init_k3s_userdata" {
  content_type = "snippets"
  datastore_id = "local"
  overwrite    = true
  node_name    = local.k3s.proxmox_node

  source_file {
    path      = local_file.cloud_init_k3s_userdata.filename
    file_name = "cloud_init_k3s_userdata.yml"
  }
}

# Transfer the cloud-init network file to the Proxmox Host
resource "proxmox_virtual_environment_file" "cloud_init_k3s_network" {
  content_type = "snippets"
  datastore_id = "local"
  overwrite    = true
  node_name    = local.k3s.proxmox_node

  source_file {
    path      = local_file.cloud_init_k3s_network.filename
    file_name = "cloud_init_k3s_network.yml"
  }
}


resource "proxmox_virtual_environment_vm" "vm_k3s" {
  # Wait for the cloud-config file to exist
  depends_on = [
    proxmox_virtual_environment_file.cloud_init_k3s_userdata,
    proxmox_virtual_environment_file.cloud_init_k3s_network
  ]

  vm_id     = local.k3s.vmid
  name      = local.k3s.hostname
  node_name = local.k3s.proxmox_node

  started = true
  on_boot = local.k3s.onboot

  agent {
    enabled = true
  }

  clone {
    vm_id = local.k3s.template_vmid
    full  = true
  }

  operating_system {
    type = "l26"
  }

  initialization {
    datastore_id         = "local-zfs"
    interface            = "ide2"
    user_data_file_id    = proxmox_virtual_environment_file.cloud_init_k3s_userdata.id
    network_data_file_id = proxmox_virtual_environment_file.cloud_init_k3s_network.id
  }

  memory {
    dedicated = local.k3s.memory
    floating  = local.k3s.memory
  }
  cpu {
    cores = local.k3s.cores
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

  # Ignore changes to the network
  ## MAC address is generated on every apply, causing
  ## TF to think this needs to be rebuilt on every apply
  lifecycle {
    ignore_changes = [
      network_device
    ]
  }
}

# Wait for cloud-init completed, reboot vm
resource "null_resource" "vm_k3s_reboot" {
  depends_on = [proxmox_virtual_environment_vm.vm_k3s]

  provisioner "remote-exec" {
    connection {
      type  = "ssh"
      user  = var.userdata.user_name
      agent = true
      host  = local.k3s.ipv4_address
    }
    inline = [
      "sudo cloud-init status --wait",
      "sudo shutdown -r +0"
    ]
  }
}
