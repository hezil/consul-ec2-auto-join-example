variable "aws_region" {
  description = "AWS region to create the environment"
}

variable "aws_access_key" {
  description = "AWS access key for account"
}

variable "aws_secret_key" {
  description = "AWS secret for account"
}

variable "instance_type" {
  default = "t2.micro"
}

variable "namespace" {
  description = <<EOH
The namespace to create the virtual training lab. This should describe the
training and must be unique to all current trainings. IAM users, workstations,
and resources will be scoped under this namespace.

It is best if you add this to your .tfvars file so you do not need to type
it manually with each run
EOH
}

variable "servers" {
  description = "The number of consul servers."
}

variable "clients" {
  description = "The number of consul client instances"
}

variable "k8s_m" {
  description = "The number of k8s_m instances"
}

variable "consul_version" {
  description = "The version of Consul to install (server and client)."
  default     = "1.4.0"
}

variable "vpc_cidr_block" {
  description = "The top-level CIDR block for the VPC."
  default     = "10.1.0.0/16"
}

variable "cidr_blocks" {
  description = "The CIDR blocks to create the workstations in."
  default     = ["10.1.1.0/24", "10.1.2.0/24"]
}

variable "consul_join_tag_key" {
  description = "The key of the tag to auto-jon on EC2."
  default     = "consul_join"
}

variable "consul_join_tag_value" {
  description = "The value of the tag to auto-join on EC2."
  default     = "training"
}

variable "public_key_path" {
  description = "The absolute path on disk to the SSH public key."
  default     = "~/.ssh/id_rsa.pub"
}

variable "key_name" {
  description = "name of ssh key to attach to hosts"
    default     = "hezkeypair"
  
}

variable "ami" {
  description = "ami to use - based on region"
  default = {
#     "us-east-1" = "ami-0565af6e282977273"
#     "us-east-2" = "ami-0ff893fa6276f28ef"
    "us-east-2" = "ami-0450f6efcdce7c116"
  }
}
