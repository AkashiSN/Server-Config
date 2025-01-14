resource "aws_security_group" "eks_cluster" {
  name        = "${var.project}_sg-eks-cluster"
  description = "${var.project}_sg-eks-cluster"
  vpc_id      = var.vpc.id

  ingress {
    description = "allow-all-from-self-sg"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  ingress {
    description = "allow-all-from-remote-node"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = var.cluster_network.remote_node_cidrs
  }

  ingress {
    description = "allow-all-from-remote-pod"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = var.cluster_network.remote_pod_cidrs
  }

  egress {
    description = "allow-all-outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}_sg-eks-cluster"
  }
}

resource "aws_security_group" "eks_worker_nodes" {
  name        = "${var.project}_sg-eks-worker_nodes"
  description = "${var.project}_sg-eks-worker_nodes"
  vpc_id      = var.vpc.id

  egress {
    description = "allow-all-outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}_sg-eks-worker_nodes"
  }
}
