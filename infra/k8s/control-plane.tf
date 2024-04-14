# Source the Cloud Init userdata Config file
data "template_file" "cloud_init_k8s_control_plane_userdata" {
  template = file("${path.module}/cloud-inits/userdata.yml.tftpl")

  vars = {
    hostname        = local.k8s_control_plane.hostname
    user_name       = var.userdata.user_name
    hashed_password = var.userdata.hashed_password
    github_id       = var.userdata.github_id
  }
}

# Source the Cloud Init network Config file
data "template_file" "cloud_init_k8s_control_plane_network" {
  template = file("${path.module}/cloud-inits/network.yml.tftpl")

  vars = {
    ipv4_address          = local.k8s_control_plane.ipv4_address
    ipv4_prefix           = local.k8s_control_plane.ipv4_prefix
    ipv4_default_gateway  = local.k8s_control_plane.ipv4_default_gateway
    ipv6_address_token    = local.k8s_control_plane.ipv6_address_token
    nas_interface_address = ""
  }
}

# Create a local copy of the file, to transfer to Proxmox
resource "local_file" "cloud_init_k8s_control_plane_userdata" {
  content  = data.template_file.cloud_init_k8s_control_plane_userdata.rendered
  filename = "${path.module}/.tmp/cloud_init_k8s_control_plane_userdata.yml"
}

# Create a local copy of the file, to transfer to Proxmox
resource "local_file" "cloud_init_k8s_control_plane_network" {
  content  = data.template_file.cloud_init_k8s_control_plane_network.rendered
  filename = "${path.module}/.tmp/cloud_init_k8s_control_plane_network.yml"
}

# Transfer the cloud-init userdata file to the Proxmox Host
resource "proxmox_virtual_environment_file" "cloud_init_k8s_control_plane_userdata" {
  content_type = "snippets"
  datastore_id = "local"
  overwrite    = true
  node_name    = local.k8s_control_plane.proxmox_node

  source_file {
    path      = local_file.cloud_init_k8s_control_plane_userdata.filename
    file_name = "cloud_init_k8s_control_plane_userdata.yml"
  }
}

# Transfer the cloud-init network file to the Proxmox Host
resource "proxmox_virtual_environment_file" "cloud_init_k8s_control_plane_network" {
  content_type = "snippets"
  datastore_id = "local"
  overwrite    = true
  node_name    = local.k8s_control_plane.proxmox_node

  source_file {
    path      = local_file.cloud_init_k8s_control_plane_network.filename
    file_name = "cloud_init_k8s_control_plane_network.yml"
  }
}

resource "proxmox_virtual_environment_vm" "vm_k8s_control_plane" {
  # Wait for the cloud-config file to exist
  depends_on = [
    proxmox_virtual_environment_file.cloud_init_k8s_control_plane_userdata,
    proxmox_virtual_environment_file.cloud_init_k8s_control_plane_network
  ]

  vm_id     = local.k8s_control_plane.vmid
  name      = local.k8s_control_plane.hostname
  node_name = local.k8s_control_plane.proxmox_node

  started = true
  on_boot = local.k8s_control_plane.onboot

  bios    = "seabios"
  machine = "pc"

  startup {
    order = "3"
  }

  agent {
    enabled = true
  }

  clone {
    vm_id = local.k8s_control_plane.template_vmid
    full  = true
  }

  operating_system {
    type = "l26"
  }

  initialization {
    datastore_id         = "local-zfs"
    interface            = "ide2"
    user_data_file_id    = proxmox_virtual_environment_file.cloud_init_k8s_control_plane_userdata.id
    network_data_file_id = proxmox_virtual_environment_file.cloud_init_k8s_control_plane_network.id
  }

  memory {
    dedicated = local.k8s_control_plane.memory
    floating  = local.k8s_control_plane.memory
  }
  cpu {
    cores = local.k8s_control_plane.cores
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
resource "null_resource" "vm_k8s_control_plane_reboot" {
  depends_on = [proxmox_virtual_environment_vm.vm_k8s_control_plane]

  provisioner "remote-exec" {
    connection {
      type  = "ssh"
      user  = var.userdata.user_name
      agent = true
      host  = local.k8s_control_plane.ipv4_address
    }
    inline = [
      "sudo cloud-init status --wait",
      "sudo shutdown -r +0"
    ]
  }
}
