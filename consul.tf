# Create the user-data for the Consul server
data "template_file" "consul_server" {
  count    = "${var.servers}"
  template = "${file("${path.module}/templates/consul.sh.tpl")}"

  vars {
    consul_version = "${var.consul_version}"
    config = <<EOF
     "node_name": "opsschool-server-${count.index+1}",
     "server": true,
     "bootstrap_expect": 3,
     "ui": true,
     "client_addr": "0.0.0.0"
    EOF
  }
}

# Create the user-data for the Consul agent
data "template_file" "consul_client" {
  count    = "${var.clients}"
  template = "${file("${path.module}/templates/consul.sh.tpl")}"

  vars {
    consul_version = "${var.consul_version}"
    config = <<EOF
     "node_name": "opsschool-client-${count.index+1}",
     "enable_script_checks": true,
     "server": false
    EOF
  }
}

# Create the Consul cluster
resource "aws_instance" "server" {
  count = "${var.servers}"

  ami           = "${lookup(var.ami, var.region)}"
  instance_type = "${var.instance_type}"
  key_name      = "${var.key_name}"

  subnet_id              = "${element(aws_subnet.consul.*.id, count.index)}"
  iam_instance_profile   = "${aws_iam_instance_profile.consul-join.name}"
  vpc_security_group_ids = ["${aws_security_group.opsschool_consul.id}"]

  tags = {
    ConsulName = "opsschool-server-${count.index+1}"
    consul_server = "true"
    "Name", "k8s_m${count.index}",
    "Group", "k8s_m",
    "Role","k8s"
  )}"

  user_data = "${element(data.template_file.consul_server.*.rendered, count.index)}"
}


resource "aws_instance" "consul_client" {
  count = "${var.clients}"

  ami           = "${lookup(var.ami, var.region)}"
  instance_type = "t2.micro"
  key_name      = "${var.key_name}"


  subnet_id              = "${element(aws_subnet.consul.*.id, count.index)}"
  iam_instance_profile   = "${aws_iam_instance_profile.consul-join.name}"
  vpc_security_group_ids = ["${aws_security_group.consul.id}"]

  tags = {
    Name = "opsschool-client-${count.index+1}"

    "Name", "k8s_s${count.index}",
    "Group", "k8s_s",
    "Role","k8s"
  )}"

  user_data = "${element(data.template_file.consul_client.*.rendered, count.index)}"
}

resource "aws_elb" "webapp_load_balancer" {
  name            = "Production-WebApp-LoadBalancer"
  internal        = false
  //instances        = ["${element(aws_instance.consul_client.*.id, count.index)}"]
  instances        = ["${aws_instance.consul_client.*.id}"]
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
  value = ["${aws_instance.consul_server.*.public_ip}"]
}

output "clients" {
  value = ["${aws_instance.consul_client.*.public_ip}"]
}
