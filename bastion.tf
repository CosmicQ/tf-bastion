##########################################################
# Create the Bastion server
resource "aws_eip" "bastion-eip" {
  instance = "${aws_instance.bastion.id}"
  vpc      = true
  instance = "${module.ec2.id[0]}"

  tags = {
    Name        = "BastionEIP"
    Terraform   = "true"
    Environment = "${var.env}"
    Workspace   = "${terraform.workspace}"
  }

}

##########################################################
# Create the bastion host + ASG
module "asg" {
  source               = "terraform-aws-modules/autoscaling/aws"
  version              = "2.9.1"

  name                 = "bastion-asg"

  # Launch configuration
  lc_name              = "bastion-lc"
  key_name             = "${var.bastion_key_name}"

  image_id             = "${data.aws_ami.amazon_linux.id}"
  instance_type        = "${var.bastion_instance_type}"
  security_groups      = ["${aws_security_group.bastion_sg.id}"]
  user_data            = "${file("${var.bastion_user_data}")}"
  iam_instance_profile = "bastion-profile"

  ebs_block_device = [
    {
      device_name           = "/dev/xvdz"
      volume_type           = "gp2"
      volume_size           = "10"
      delete_on_termination = true
    },
  ]

  root_block_device = [
    {
      volume_size = "10"
      volume_type = "gp2"
    },
  ]

  # Auto scaling group
  asg_name                  = "bastion-asg"
  vpc_zone_identifier       = ["${element(module.vpc.private_subnets, 0)}", "${element(module.vpc.private_subnets, 1)}"]
  health_check_type         = "EC2"
  min_size                  = "${var.bastion_min_size}"
  max_size                  = "${var.bastion_max_size}"
  desired_capacity          = "${var.bastion_desired_capacity}"
  wait_for_capacity_timeout = 0

  tags = [
    {
      key                 = "Terraform"
      value               = "true"
      propagate_at_launch = true
    },
    {
      key                 = "Workspace"
      value               = "${terraform.workspace}"
      propagate_at_launch = true
    }
  ]

}