terraform {
  backend "s3" {
  region="us-east-2"
  key="layer2/backend.tfstate"
  bucket="terraform-remote-state-11.03.2019"
  }
}

data "terraform_remote_state" "network_configuration" {
  backend = "s3"

  config {
    bucket = "terraform-remote-state-11.03.2019"
    key    = "layer1/infrastructure.tfstate"
    region = "us-east-2"
    access_key = ""
    secret_key = ""
  }
}

# Create the user-data for the Consul server
data "template_file" "server" {
  count    = "${var.servers}"
  template = "${file("${path.module}/templates/consul.sh.tpl")}"

  vars {
    consul_version = "0.7.5"

    config = <<EOF
     "bootstrap_expect": 3,
     "ui": true,
     "node_name": "${var.namespace}-server-${count.index}",
     "retry_join_ec2": {
       "tag_key": "${var.consul_join_tag_key}",
       "tag_value": "${var.consul_join_tag_value}"
     },
     "server": true
    EOF
  }
}

# Create the user-data for the Consul server
data "template_file" "client" {
  count    = "${var.clients}"
  template = "${file("${path.module}/templates/consul.sh.tpl")}"
  vars {
    consul_version = "0.7.5"

    config = <<EOF
     "node_name": "${var.namespace}-client-${count.index}",
     "retry_join_ec2": {
       "tag_key": "${var.consul_join_tag_key}",
       "tag_value": "${var.consul_join_tag_value}"
     },
     "server": false
    EOF
  }
}

# Create the Consul cluster
resource "aws_instance" "server" {
  count = "${var.servers}"

  ami           = "ami-0450f6efcdce7c116"
  instance_type = "${var.instance_type}"
  key_name      = "${aws_key_pair.consul.id}"

  subnet_id              = "${element(aws_subnet.consul.*.id, count.index)}"
  iam_instance_profile   = "${aws_iam_instance_profile.consul-join.name}"
  vpc_security_group_ids = ["${aws_security_group.consul.id}"]

  tags = "${map(
    "ConsulName", "${var.namespace}-server-${count.index}",
    var.consul_join_tag_key, var.consul_join_tag_value,
    "Name", "k8s_m${count.index}",
    "Group", "k8s_m",
    "Role","k8s"
  )}"

  user_data = "${element(data.template_file.server.*.rendered, count.index)}"
}

resource "aws_instance" "client" {
  count = "${var.clients}"

  ami           = "ami-0450f6efcdce7c116"
  instance_type = "${var.instance_type}"
  key_name      = "${aws_key_pair.consul.id}"

  subnet_id              = "${element(aws_subnet.consul.*.id, count.index)}"
  iam_instance_profile   = "${aws_iam_instance_profile.consul-join.name}"
  vpc_security_group_ids = ["${aws_security_group.consul.id}"]

  tags = "${map(
    "CosulName", "${var.namespace}-client-${count.index}",
    var.consul_join_tag_key, var.consul_join_tag_value,
    "Name", "k8s_s${count.index}",
    "Group", "k8s_s",
    "Role","k8s"
  )}"

  user_data = "${element(data.template_file.client.*.rendered, count.index)}"
}

resource "aws_elb" "webapp_load_balancer" {
  name            = "Production-WebApp-LoadBalancer"
  internal        = false
  //instances        = ["${element(aws_instance.client.*.id, count.index)}"]
  instances        = ["${aws_instance.client.*.id}"]
  security_groups = ["${aws_security_group.consul.id}"]
  subnets = ["${aws_subnet.consul.*.id}"]
  "listener" {
    instance_port = 30036
    instance_protocol = "HTTP"
    lb_port = 80
    lb_protocol = "HTTP"
  }
  health_check {
    healthy_threshold   = 5
    interval            = 30
    target              = "HTTP:30036/"
    timeout             = 10
    unhealthy_threshold = 5
  }
}

output "servers" {
  value = ["${aws_instance.server.*.public_ip}"]
}

output "clients" {
  value = ["${aws_instance.client.*.public_ip}"]
}
