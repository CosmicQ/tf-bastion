##########################################################
# Define Variables
variable "vpc_zone_identifier" {
  # This is intended to be used with the vpc terraform module.  This can be modified to
  # specifiy two public subnets though.
  default = ["${element(module.vpc.public_subnets, 0)}", "${element(module.vpc.public_subnets, 1)}"]
  # default = ["10.10.1.0/24", "10.10.2.0/24"]
}

variable "bastion_key_name" {}
variable "bastion_ingress" {
  default = ["0.0.0.0/0"]
}
variable "bastion_instance_type" {
  default = "t2.nano"
}
variable "bastion_min_size" {
  default = "1"
}
variable "bastion_max_size" {
  default = "1"
}
variable "bastion_desired_capacity" {
  default = "1"
}
variable "bastion_user_data" {
  default = "files/bastion_userdata.sh"
}


##########################################################
# Get AMI
data "aws_ami" "amazon_linux" {
  most_recent = true

  filter {
    name = "name"

    values = [
      "amzn-ami-hvm-*-x86_64-gp2",
    ]
  }

  filter {
    name = "owner-alias"

    values = [
      "amazon",
    ]
  }
}