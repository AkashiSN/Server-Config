resource "oci_core_virtual_network" "main" {
  compartment_id = var.compartment_id

  cidr_block   = "10.0.0.0/16"
  display_name = "main-vcn"
  dns_label    = "mainvcn"
}

resource "oci_core_subnet" "main" {
  compartment_id = var.compartment_id

  cidr_block        = "10.0.1.0/24"
  vcn_id            = oci_core_virtual_network.main.id
  display_name      = "main-subnet"
  dns_label         = "mainsubnet"
  security_list_ids = [oci_core_security_list.main.id]
  route_table_id    = oci_core_route_table.main.id
}

resource "oci_core_security_list" "main" {
  compartment_id = var.compartment_id

  vcn_id       = oci_core_virtual_network.main.id
  display_name = "main-security-list"

  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"
    tcp_options {
      max = 22 # SSH
      min = 22
    }
  }

  ingress_security_rules {
    protocol = "17" # UDP
    source   = "0.0.0.0/0"
    udp_options {
      max = 53 # DNS
      min = 53
    }
  }

  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"
    tcp_options {
      min = 443 # HTTPS
      max = 443
    }
  }

  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"
    tcp_options {
      min = 853 # DoH
      max = 853
    }
  }

  ingress_security_rules {
    protocol = "17" # UDP
    source   = "0.0.0.0/0"
    udp_options {
      max = 51820 # Wireguard
      min = 51820
    }
  }

  ingress_security_rules {
    protocol = "1" # ICMP
    source   = "0.0.0.0/0"
  }

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }
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

  vcn_id = oci_core_virtual_network.main.id

  display_name = "main-internet-gateway"
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
    assign_public_ip = true
    subnet_id        = oci_core_subnet.main.id
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data = base64encode(templatefile("${path.module}/template/k3s_userdata.sh.tftpl", {
      hostname            = "k3s-oci"
      wireguard_server_ip = "10.254.0.1"
    }))
  }
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
