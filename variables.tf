##########################################################
# Define Variables
variable "vpc_id" { }

variable "public_subnets" {
  type        = "list"
  #["${element(module.vpc.public_subnets, 0)}", "${element(module.vpc.public_subnets, 1)}"]
}
variable "bastion_name" {
  type        = "string"
  default     = "bastion"
}
variable "bastion_key_name" {
  type        = "string"
  default     = "default"
}
variable "bastion_ingress" {
  default     = ["0.0.0.0/0"]
}
variable "bastion_instance_type" {
  default     = "t2.nano"
}
variable "bastion_min_size" {
  default     = "1"
}
variable "bastion_max_size" {
  default     = "1"
}
variable "bastion_desired_capacity" {
  default     = "1"
}
variable "bastion_user_data" {
  default     = "${path.module}/files/bastion_userdata.sh"
}

variable "bastion_s3_bucket" {}

variable "create_bastion_dns" {
  description = "Boolean to determine if we would like to create a DNS record"
  default     = false
}

variable "bastion_domain" {
  description = "Domain name to use for bastion server (foo.com not bastion.foo.com)"
  type        = "string"
  default     = ""
}

variable "environment" {
  default     = ""
}

##########################################################
# Get AMI
data "aws_ami" "amazon_linux2" {
 most_recent  = true
 owners       = ["amazon"]

 filter {
   name   = "owner-alias"
   values = ["amazon"]
 }

 filter {
   name   = "name"
   values = ["amzn2-ami-hvm*x86_64-gp2"]
 }
 
}

##########################################################
# Get userdata
data "template_file" "userdata" {
  template = "${file("${var.bastion_user_data}")}"
  vars = {
    bastion_name = "${var.bastion_name}"
  }
}
