data "aws_ami" "eks-worker-gpu" {
  filter {
    name   = "name"
    values = ["amazon-eks-gpu-node-${var.kubernetes_version}*"]
  }

  most_recent = true
  owners      = ["679593333241"] # Amazon EKS AMI Account ID
}

data "template_file" "eks-node-gpu" {
  count    = "${length(var.node-pools-gpu)}"
  template = "${file("templates/eks-node.tpl")}"

  vars {
    apiserver_endpoint = "${aws_eks_cluster.eks.endpoint}"
    b64_cluster_ca     = "${aws_eks_cluster.eks.certificate_authority.0.data}"
    cluster_name       = "${var.cluster-name}"
    kubelet_extra_args = "${lookup(var.node-pools-gpu[count.index],"kubelet_extra_args")}"
  }
}

resource "aws_launch_template" "eks-gpu" {
  count = "${length(var.node-pools-gpu)}"

  iam_instance_profile = {
    name = "${aws_iam_instance_profile.eks-node-gpu.*.name[count.index]}"
  }

  image_id               = "${data.aws_ami.eks-worker.id}"
  instance_type          = "${lookup(var.node-pools-gpu[count.index],"instance_type")}"
  name_prefix            = "terraform-eks-${var.cluster-name}-node-pool-${lookup(var.node-pools-gpu[count.index],"name")}"
  vpc_security_group_ids = ["${aws_security_group.eks-node.id}"]
  user_data              = "${base64encode(data.template_file.eks-node.*.rendered[count.index])}"

  key_name = "${lookup(var.node-pools-gpu[count.index],"key_name")}"

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size = "${lookup(var.node-pools-gpu[count.index],"volume_size")}"
      volume_type = "${lookup(var.node-pools-gpu[count.index],"volume_type")}"
    }
  }
}

resource "aws_autoscaling_group" "eks-gpu" {
  count = "${length(var.node-pools-gpu)}"

  desired_capacity = "${lookup(var.node-pools-gpu[count.index],"desired_capacity")}"

  launch_template = {
    id      = "${aws_launch_template.eks.*.id[count.index]}"
    version = "$$Latest"
  }

  max_size            = "${lookup(var.node-pools-gpu[count.index],"max_size")}"
  min_size            = "${lookup(var.node-pools-gpu[count.index],"min_size")}"
  name                = "terraform-eks-${var.cluster-name}-node-pool-${lookup(var.node-pools-gpu[count.index],"name")}"
  vpc_zone_identifier = ["${split(",", var.vpc["create"] ? join(",", aws_subnet.eks-private.*.id) : var.vpc["private_subnets_id"])}"]

  tag {
    key                 = "Name"
    value               = "terraform-eks-${var.cluster-name}"
    propagate_at_launch = true
  }

  tag {
    key                 = "kubernetes.io/cluster/${var.cluster-name}"
    value               = "owned"
    propagate_at_launch = true
  }

  tag {
    key                 = "k8s.io/cluster-autoscaler/${lookup(var.node-pools-gpu[count.index],"autoscaling")}"
    value               = ""
    propagate_at_launch = true
  }

  tag {
    key                 = "k8s.io/cluster-autoscaler/${var.cluster-name}"
    value               = ""
    propagate_at_launch = true
  }

  tag {
    key                 = "eks:node-pool:name"
    value               = "${lookup(var.node-pools-gpu[count.index],"name")}"
    propagate_at_launch = true
  }
}
