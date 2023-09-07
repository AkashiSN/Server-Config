# Source the Cloud Init userdata Config file
data "template_file" "cloud_init_microk8s_userdata" {
  template = file("${path.module}/cloud-inits/userdata.yml.tftpl")

  vars = {
    hostname        = local.microk8s.hostname
    user_name       = var.userdata.user_name
    hashed_password = var.userdata.hashed_password
    github_id       = var.github_id
  }
}

# Source the Cloud Init network Config file
data "template_file" "cloud_init_microk8s_network" {
  template = file("${path.module}/cloud-inits/network.yml.tftpl")

  vars = {
    ipv4_address          = local.microk8s.ipv4_address
    ipv4_default_gateway  = local.microk8s.ipv4_default_gateway
  }
}

# Create a local copy of the file, to transfer to Proxmox
resource "local_file" "cloud_init_microk8s_userdata" {
  content  = data.template_file.cloud_init_microk8s_userdata.rendered
  filename = "${path.module}/.tmp/cloud_init_microk8s_userdata.yml"
}

# Create a local copy of the file, to transfer to Proxmox
resource "local_file" "cloud_init_microk8s_network" {
  content  = data.template_file.cloud_init_microk8s_network.rendered
  filename = "${path.module}/.tmp/cloud_init_microk8s_network.yml"
}

# Transfer the file to the Proxmox Host
resource "null_resource" "cloud_init_microk8s_userdata" {
  connection {
    type        = "ssh"
    user        = "root"
    private_key = file("~/.ssh/id_ed25519")
    host        = local.microk8s.proxmox_address
  }

  provisioner "file" {
    source      = local_file.cloud_init_microk8s_userdata.filename
    destination = "/var/lib/vz/snippets/cloud_init_microk8s_userdata.yml"
  }
}

# Transfer the file to the Proxmox Host
resource "null_resource" "cloud_init_microk8s_network" {
  connection {
    type        = "ssh"
    user        = "root"
    private_key = file("~/.ssh/id_ed25519")
    host        = local.microk8s.proxmox_address
  }

  provisioner "file" {
    source      = local_file.cloud_init_microk8s_network.filename
    destination = "/var/lib/vz/snippets/cloud_init_microk8s_network.yml"
  }
}

resource "proxmox_vm_qemu" "vm-microk8s" {
  # Wait for the cloud-config file to exist
  depends_on = [
    null_resource.cloud_init_microk8s_userdata,
    null_resource.cloud_init_microk8s_network
  ]

  vmid        = local.microk8s.vmid
  name        = local.microk8s.hostname
  target_node = local.microk8s.proxmox_node

  clone      = "ubuntu2204-server-template"
  full_clone = true
  os_type    = "cloud-init"

  cicustom = "user=local:snippets/cloud_init_microk8s_userdata.yml,network=local:snippets/cloud_init_microk8s_network.yml"

  memory  = local.microk8s.memory
  cores   = local.microk8s.cores
  qemu_os = "l26"
  agent   = 1
  onboot  = local.microk8s.onboot

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

  # Ignore changes to the network
  ## MAC address is generated on every apply, causing
  ## TF to think this needs to be rebuilt on every apply
  lifecycle {
    ignore_changes = [
      network
    ]
  }
}
