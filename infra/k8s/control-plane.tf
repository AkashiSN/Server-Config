# Source the Cloud Init userdata Config file
data "template_file" "cloud_init_k8s_control_plane_userdata" {
  template = file("${path.module}/cloud-inits/userdata.yml.tftpl")

  vars = {
    hostname        = local.k8s_control_plane.hostname
    user_name       = var.userdata.user_name
    hashed_password = var.userdata.hashed_password
    github_id       = var.github_id
  }
}

# Source the Cloud Init network Config file
data "template_file" "cloud_init_k8s_control_plane_network" {
  template = file("${path.module}/cloud-inits/network.yml.tftpl")

  vars = {
    ipv4_address          = local.k8s_control_plane.ipv4_address
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

# Transfer the file to the Proxmox Host
resource "null_resource" "cloud_init_k8s_control_plane_userdata" {
  connection {
    type        = "ssh"
    user        = "root"
    private_key = file("~/.ssh/id_ed25519")
    host        = local.k8s_control_plane.proxmox_address
  }

  provisioner "file" {
    source      = local_file.cloud_init_k8s_control_plane_userdata.filename
    destination = "/var/lib/vz/snippets/cloud_init_k8s_control_plane_userdata.yml"
  }
}

# Transfer the file to the Proxmox Host
resource "null_resource" "cloud_init_k8s_control_plane_network" {
  connection {
    type        = "ssh"
    user        = "root"
    private_key = file("~/.ssh/id_ed25519")
    host        = local.k8s_control_plane.proxmox_address
  }

  provisioner "file" {
    source      = local_file.cloud_init_k8s_control_plane_network.filename
    destination = "/var/lib/vz/snippets/cloud_init_k8s_control_plane_network.yml"
  }
}

resource "proxmox_vm_qemu" "vm-k8s_control_plane" {
  # Wait for the cloud-config file to exist
  depends_on = [
    null_resource.cloud_init_k8s_control_plane_userdata,
    null_resource.cloud_init_k8s_control_plane_network
  ]

  vmid        = local.k8s_control_plane.vmid
  name        = local.k8s_control_plane.hostname
  target_node = local.k8s_control_plane.proxmox_node

  clone      = "ubuntu2204-server-template"
  full_clone = true
  os_type    = "cloud-init"

  cicustom = "user=local:snippets/cloud_init_k8s_control_plane_userdata.yml,network=local:snippets/cloud_init_k8s_control_plane_network.yml"

  memory  = local.k8s_control_plane.memory
  cores   = local.k8s_control_plane.cores
  qemu_os = "l26"
  agent   = 1
  onboot  = local.k8s_control_plane.onboot

  boot     = "order=scsi0"
  scsihw   = "virtio-scsi-pci"

  disk {
    size    = "128G"
    type    = "scsi"
    storage = "local-zfs"
    ssd     = 1
  }

  network {
    model  = "virtio"
    bridge = "vmbr0"
  }

  network {
    model  = "virtio"
    bridge = "vmbr1"
  }

  # Ignore changes to the network
  ## MAC address is generated on every apply, causing
  ## TF to think this needs to be rebuilt on every apply
  lifecycle {
    ignore_changes = [
      network
    ]
  }
}
