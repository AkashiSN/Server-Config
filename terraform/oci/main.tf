resource "oci_core_virtual_network" "main" {
  compartment_id = var.compartment_id

  cidr_block   = "10.0.0.0/16"
  display_name = "main-vcn"
  dns_label    = "mainvcn"
}

resource "oci_core_subnet" "main" {
  compartment_id = var.compartment_id

  cidr_block     = "10.0.1.0/24"
  vcn_id         = oci_core_virtual_network.main.id
  display_name   = "main-subnet"
  dns_label      = "mainsubnet"
  route_table_id = oci_core_route_table.main.id
}

resource "oci_core_route_table" "main" {
  compartment_id = var.compartment_id

  vcn_id       = oci_core_virtual_network.main.id
  display_name = "main-route-table"

  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = oci_core_internet_gateway.main.id
  }
}

resource "oci_core_internet_gateway" "main" {
  compartment_id = var.compartment_id

  vcn_id       = oci_core_virtual_network.main.id
  display_name = "main-internet-gateway"
}

resource "oci_core_network_security_group" "main" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_virtual_network.main.id

  display_name = "main-security-group"
}

resource "oci_core_network_security_group_security_rule" "ingress_ssh" {
  network_security_group_id = oci_core_network_security_group.main.id

  direction = "INGRESS"
  protocol  = "6" # TCP
  source    = "0.0.0.0/0"
  tcp_options {
    destination_port_range {
      max = 22 # SSH
      min = 22
    }
  }
}

resource "oci_core_network_security_group_security_rule" "ingress_dns" {
  network_security_group_id = oci_core_network_security_group.main.id

  direction = "INGRESS"
  protocol  = "17" # UDP
  source    = "0.0.0.0/0"
  udp_options {
    destination_port_range {
      max = 53 # DNS
      min = 53
    }
  }
}

resource "oci_core_network_security_group_security_rule" "ingress_https" {
  network_security_group_id = oci_core_network_security_group.main.id

  direction = "INGRESS"
  protocol  = "6" # TCP
  source    = "0.0.0.0/0"
  tcp_options {
    destination_port_range {
      max = 443 # HTTPS
      min = 443
    }
  }
}

resource "oci_core_network_security_group_security_rule" "ingress_doh" {
  network_security_group_id = oci_core_network_security_group.main.id

  direction = "INGRESS"
  protocol  = "6" # TCP
  source    = "0.0.0.0/0"
  tcp_options {
    destination_port_range {
      max = 853 # DoH
      min = 853
    }
  }
}

resource "oci_core_network_security_group_security_rule" "ingress_wireguard" {
  network_security_group_id = oci_core_network_security_group.main.id

  direction = "INGRESS"
  protocol  = "17" # UDP
  source    = "0.0.0.0/0"
  udp_options {
    destination_port_range {
      max = 51820 # Wireguard
      min = 51820
    }
  }
}

resource "oci_core_network_security_group_security_rule" "egress_all" {
  network_security_group_id = oci_core_network_security_group.main.id

  direction   = "EGRESS"
  protocol    = "all" # 全てのプロトコル
  destination = "0.0.0.0/0"
}

resource "oci_core_instance" "ubuntu_instance" {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  compartment_id      = var.compartment_id

  shape = "VM.Standard.E4.Flex"
  shape_config {
    baseline_ocpu_utilization = "BASELINE_1_8"
    ocpus                     = 4
    memory_in_gbs             = 16
  }

  source_details {
    # oci compute image list --display-name "Canonical-Ubuntu-24.04-2025.09.22-0"
    source_id   = "ocid1.image.oc1.ap-tokyo-1.aaaaaaaaewdrshfelq3ol2trqtxszyqr3rctikgkzutr7uyiisatbfipfzsq"
    source_type = "image"

    boot_volume_size_in_gbs = 100
  }

  display_name = "k3s-server"

  create_vnic_details {
    assign_public_ip = false
    private_ip       = "10.0.1.10"
    subnet_id        = oci_core_subnet.main.id
    nsg_ids          = [oci_core_network_security_group.main.id]
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data = base64encode(templatefile("${path.module}/template/k3s_userdata.sh.tftpl", {
      hostname            = "k3s-oci"
      wireguard_server_ip = "10.254.0.1"
    }))
  }
}

data "oci_core_vnic_attachments" "ubuntu_instance" {
  compartment_id      = var.compartment_id
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  instance_id         = oci_core_instance.ubuntu_instance.id
}

data "oci_core_vnic" "ubuntu_instance_primary_vnic" {
  vnic_id = data.oci_core_vnic_attachments.ubuntu_instance.vnic_attachments[0].vnic_id
}

data "oci_core_private_ips" "ubuntu_instance_private_ips" {
  vnic_id = data.oci_core_vnic.ubuntu_instance_primary_vnic.id
}

resource "oci_core_public_ip" "ubuntu_instance_reserved_public_ip" {
  compartment_id = var.compartment_id
  lifetime       = "RESERVED"
  display_name   = "k3s-public-ip"
  private_ip_id  = data.oci_core_private_ips.ubuntu_instance_private_ips.private_ips[0].id
}

resource "oci_core_volume" "main" {
  compartment_id      = var.compartment_id
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  display_name        = "main-volume"
  size_in_gbs         = "2048"
  vpus_per_gb         = "0"
}

resource "oci_core_volume_attachment" "main" {
  attachment_type = "paravirtualized"
  instance_id     = oci_core_instance.ubuntu_instance.id
  volume_id       = oci_core_volume.main.id
}
