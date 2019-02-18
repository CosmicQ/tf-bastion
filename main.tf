##########################################################
# Define Variables
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