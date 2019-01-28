resource "aws_iam_role" "eks-cluster" {
  name = "eks-cluster"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "eks-cluster-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = "${aws_iam_role.eks-cluster.name}"
}

resource "aws_iam_role_policy_attachment" "eks-cluster-AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = "${aws_iam_role.eks-cluster.name}"
}

/* Security group for the cluster */
resource "aws_security_group" "eks-cluster" {
  name        = "eks-cluster"
  description = "Cluster communication with worker nodes"
  vpc_id      = "${aws_vpc.vpc-main.id}"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name    = "eks-cluster"
    stage   = "poc"
    creator = "terraform"
  }
}

/* EKS - master cluster */
resource "aws_eks_cluster" "eks-test" {
  name     = "eks-test"
  role_arn = "${aws_iam_role.eks-cluster.arn}"

  vpc_config {
    security_group_ids = ["${aws_security_group.eks-cluster.id}"]
    subnet_ids = ["${aws_subnet.sn-pub.*.id}"]
  }

  depends_on = [
    "aws_iam_role_policy_attachment.eks-cluster-AmazonEKSClusterPolicy",
    "aws_iam_role_policy_attachment.eks-cluster-AmazonEKSServicePolicy",
  ]
}

/* worker roles */
resource "aws_iam_role" "eks-node" {
  name = "eks-node"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "eks-node-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = "${aws_iam_role.eks-node.name}"
}

resource "aws_iam_role_policy_attachment" "eks-node-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = "${aws_iam_role.eks-node.name}"
}

resource "aws_iam_role_policy_attachment" "eks-node-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = "${aws_iam_role.eks-node.name}"
}

resource "aws_iam_instance_profile" "eks-node" {
  name = "eks-node"
  role = "${aws_iam_role.eks-node.name}"
}

/* worker node security group */
resource "aws_security_group" "eks-node" {
  name = "eks-node"
  description = "Security group for nodes"
  vpc_id = "${aws_vpc.vpc-main.id}"

  egress {
    from_port = 0
    to_port   = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = "${
      map(
        "Name", "eks-node",
        "kubernetes.io/cluster/${var.clname}", "owned"
      )
    }"
}

resource "aws_security_group_rule" "eks-node-ingress-self" {
  description = "Allow node to communicate with each other"
  from_port   = 0
  to_port     = 65535
  protocol    = "-1"
  security_group_id        = "${aws_security_group.eks-node.id}"
  source_security_group_id = "${aws_security_group.eks-node.id}"
  type        = "ingress"
}

resource "aws_security_group_rule" "eks-node-ingress-cluster" {
  description = "Allow worker Kubelets and pods to receive communication from the cluster control plane"
  from_port   = 1025
  to_port     = 65535
  protocol    = "tcp"
  security_group_id        = "${aws_security_group.eks-node.id}"
  source_security_group_id = "${aws_security_group.eks-cluster.id}"
  type        = "ingress"
}

resource "aws_security_group_rule" "eks-cluster-ingress-node-https" {
    description = "Allow pods to communicate with the cluster API server"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    security_group_id        = "${aws_security_group.eks-cluster.id}"
    source_security_group_id = "${aws_security_group.eks-node.id}"
    type        = "ingress"
}

data "aws_ami" "eks-worker" {
  filter {
    name      = "name"
    values    = ["amazon-eks-node-*"]
  }
  most_recent = true
  owners      = ["602401143452"] # Amazon EKS AMI Account ID
}

locals {
  eks-node-userdata = <<USERDATA
#!/bin/bash
set -o xtrace
/etc/eks/bootstrap.sh --apiserver-endpoint '${aws_eks_cluster.eks-test.endpoint}' --b64-cluster-ca '${aws_eks_cluster.eks-test.certificate_authority.0.data}' '${var.clname}'
USERDATA
}

resource "aws_launch_configuration" "eks-base" {
  associate_public_ip_address = true
  iam_instance_profile        = "${aws_iam_instance_profile.eks-node.name}"
  image_id                    = "${data.aws_ami.eks-worker.id}"
  instance_type               = "${var.host-size}"
  name_prefix                 = "${var.clname}"
  security_groups             = ["${aws_security_group.eks-node.id}"]
  user_data_base64            = "${base64encode(local.eks-node-userdata)}"

  lifecycle {
    create_before_destroy     = true
  }
}

resource "aws_autoscaling_group" "eks-cluster" {
    desired_capacity     = 2
    launch_configuration = "${aws_launch_configuration.eks-base.id}"
    max_size             = 2
    min_size             = 1
    name                 = "${var.clname}-node"
    vpc_zone_identifier  = ["${aws_subnet.sn-pub.*.id}"]

    tag {
      key                 = "Name"
      value               = "eks-test"
      propagate_at_launch = true
    }

    tag {
      key   = "kubernetes.io/cluster/${var.clname}"
      value = "owned"
      propagate_at_launch = true
    }
}

locals {
  config-map-aws-auth = <<CONFIGMAPAWSAUTH


apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: ${aws_iam_role.eks-worker-node-role.arn}
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
CONFIGMAPAWSAUTH
}

output "config_map_aws_auth" {
  value = "${local.config-map-aws-auth}"
}
