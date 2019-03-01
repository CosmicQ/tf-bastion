##########################################################
# Define Variables
variable "vpc_id" { }
variable "public_subnets" {
  type    = "list"
  #["${element(module.vpc.public_subnets, 0)}", "${element(module.vpc.public_subnets, 1)}"]
}
variable "bastion_name" {
  type    = "string"
  default = "bastion"
}
variable "bastion_key_name" {
  type    = "string"
}
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

variable "bastion_s3_bucket" {
  default = "cosmic-bastion"
}
##########################################################
# Get AMI
data "aws_ami" "amazon_linux2" {
 most_recent = true
 owners      = ["amazon"]

 filter {
   name   = "owner-alias"
   values = ["amazon"]
 }

 filter {
   name   = "name"
   values = ["amzn2-ami-hvm*"]
 }
}
