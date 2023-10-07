# Source the Cloud Init userdata Config file
data "template_file" "cloud_init_worker_node_01_userdata" {
  template = file("${path.module}/cloud-inits/userdata.yml.tftpl")

  vars = {
    hostname        = local.worker_node_01.hostname
    user_name       = var.userdata.user_name
    hashed_password = var.userdata.hashed_password
    github_id       = var.github_id
  }
}

# Source the Cloud Init network Config file
data "template_file" "cloud_init_worker_node_01_network" {
  template = file("${path.module}/cloud-inits/network.yml.tftpl")

  vars = {
    ipv4_address          = local.worker_node_01.ipv4_address
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

# Transfer the file to the Proxmox Host
resource "null_resource" "cloud_init_worker_node_01_userdata" {
  connection {
    type        = "ssh"
    user        = "root"
    private_key = file("~/.ssh/id_ed25519")
    host        = local.worker_node_01.proxmox_address
  }

  provisioner "file" {
    source      = local_file.cloud_init_worker_node_01_userdata.filename
    destination = "/var/lib/vz/snippets/cloud_init_worker_node_01_userdata.yml"
  }
}

# Transfer the file to the Proxmox Host
resource "null_resource" "cloud_init_worker_node_01_network" {
  connection {
    type        = "ssh"
    user        = "root"
    private_key = file("~/.ssh/id_ed25519")
    host        = local.worker_node_01.proxmox_address
  }

  provisioner "file" {
    source      = local_file.cloud_init_worker_node_01_network.filename
    destination = "/var/lib/vz/snippets/cloud_init_worker_node_01_network.yml"
  }
}

resource "proxmox_vm_qemu" "vm-worker_node_01" {
  # Wait for the cloud-config file to exist
  depends_on = [
    null_resource.cloud_init_worker_node_01_userdata,
    null_resource.cloud_init_worker_node_01_network
  ]

  vmid        = local.worker_node_01.vmid
  name        = local.worker_node_01.hostname
  target_node = local.worker_node_01.proxmox_node

  clone      = "ubuntu2204-server-template"
  full_clone = true
  os_type    = "cloud-init"

  cicustom = "user=local:snippets/cloud_init_worker_node_01_userdata.yml,network=local:snippets/cloud_init_worker_node_01_network.yml"

  memory  = local.worker_node_01.memory
  cores   = local.worker_node_01.cores
  qemu_os = "l26"
  agent   = 1
  onboot  = local.worker_node_01.onboot

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
