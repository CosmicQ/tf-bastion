##########################################################
# Create the bastion host + ASG
module "asg" {
  source                    = "terraform-aws-modules/autoscaling/aws"

  # Autoscaling Group
  create                    = true
  name                      = "${var.bastion_name}_asg"

  min_size                  = var.bastion_min_size
  max_size                  = var.bastion_max_size
  desired_capacity          = var.bastion_desired_capacity
  wait_for_capacity_timeout = 0
  health_check_type         = "EC2"
  vpc_zone_identifier       = var.public_subnets

  # Launch Template
  create_launch_template      = true
  launch_template_name        = "${var.bastion_name}_lc"
  update_default_version      = true

  # IAM role & instance profile
  create_iam_instance_profile = true
  iam_instance_profile_arn    = aws_iam_instance_profile.bastion_profile.arn
  image_id                    = data.aws_ami.amazon_linux2.id
  instance_type               = var.bastion_instance_type
  key_name                    = var.bastion_key_name
  security_groups             = [module.bastion_sg.security_group_id]
  user_data                   = templatefile(
                                  "${path.module}/${var.bastion_user_data}",
                                  { bastion_name = var.bastion_name }
                                )

  ##########################################################

  block_device_mappings = [
    {
      device_name           = "/dev/xvdz"
      ebs = {
        volume_type           = "gp2"
        volume_size           = "20"
        delete_on_termination = true
      }
    }
  ]

  tags = {
      bastion = "true"
      s3_bucket_name = var.bastion_s3_bucket
      Terraform = "true"
      Workspace = "${terraform.workspace}"
    }
}

##########################################################
# Bastion server support resources

# Create the elastic IP
resource "aws_eip" "bastion-eip" {
  vpc      = true
  # Name        = "BastionEIP"
  tags     = {
    bastion     = "true"
    Name        = "${var.bastion_name}_eip"
    Terraform   = "true"
    Workspace   = terraform.workspace
  }
}

# Create the S3 bucket
resource "aws_s3_bucket" "bastion_bucket" {
  bucket        = var.bastion_s3_bucket
  acl           = "private"
  force_destroy = true

  tags     = {
    bastion     = "true"
    Terraform   = "true"
    Workspace   = terraform.workspace
  }
}

# Create the bastion security group
module "bastion_sg" {
  source                       = "terraform-aws-modules/security-group/aws//modules/ssh"
  name                         = "${var.bastion_name}_sg"
  description                  = "Allow traffic to Bastion"
  vpc_id                       = var.vpc_id
  ingress_cidr_blocks          = var.bastion_ingress
  tags     = {
    Name        = "BastionSG"
    Terraform   = "true"
    Workspace   = "${terraform.workspace}"
  }
}

# Create the log groups (/var/log/secure as well as commdn logs)
resource "aws_cloudwatch_log_group" "secure_lg" {
  name = "${var.environment}/var/log/secure"
}

resource "aws_cloudwatch_log_group" "commands_lg" {
  name = "${var.environment}/var/log/commands"
}

# The bastion server needs to be able to read and write to it's S3 bucket, as well as describe instances
# and apply the elastic IP to itself
resource "aws_iam_role" "bastion_role" {
  name = "${var.bastion_name}_role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy" "policy" {
  name        = "${var.bastion_name}_policy"
  description = "A set of permissions for a Bastion host"
  policy      = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "bastion0",
            "Effect": "Allow",
            "Action": [
                "ec2:DisassociateAddress",
                "tag:GetResources",
                "ec2:DescribeAddresses",
                "ec2:DescribeInstances",
                "ec2:DescribeAvailabilityZones",
                "tag:GetTagValues",
                "ec2:DescribeTags",
                "ec2:AssociateAddress",
                "logs:CreateLogGroup",
                "tag:GetTagKeys"
            ],
            "Resource": "*"
        },
        {
            "Sid": "bastion1",
            "Effect": "Allow",
            "Action": [
                "s3:*"
            ],
            "Resource": [
                         "arn:aws:s3:::${var.bastion_s3_bucket}",
                         "arn:aws:s3:::${var.bastion_s3_bucket}/*"
                        ]
        },
        {
            "Sid": "bastion2",
            "Effect": "Allow",
            "Action": [
                "logs:GetLogEvents",
                "logs:PutLogEvents"
            ],
            "Resource": "arn:aws:logs:*:*:log-group:*:*:*"
        },
        {
            "Sid": "bastion3",
            "Effect": "Allow",
            "Action": [
                "logs:PutMetricFilter",
                "logs:CreateLogStream",
                "logs:DescribeLogGroups",
                "logs:DescribeLogStreams",
                "logs:GetLogEvents",
                "logs:PutLogEvents"
            ],
            "Resource": "arn:aws:logs:*:*:log-group:*"
        }
    ]
}
EOF
}

resource "aws_iam_instance_profile" "bastion_profile" {
  name = "${var.bastion_name}_profile"
  role = aws_iam_role.bastion_role.name
}

resource "aws_iam_policy_attachment" "bastion-attach" {
  name       = "${var.bastion_name}_attachment"
  roles      = [aws_iam_role.bastion_role.name]
  policy_arn = aws_iam_policy.policy.arn
}

###################################
#
# Optional resources
#
###################################
/*
data "aws_route53_zone" "selected" {
  count      = var.create_bastion_dns
  name       = "${var.bastion_domain}."
}

resource "aws_route53_record" "bastion_name" {
  count      = var.create_bastion_dns
  zone_id    = data.aws_route53_zone.selected.zone_id
  name       = "${var.bastion_name}.${data.aws_route53_zone.selected.name}"
  type       = "A"
  ttl        = "300"
  records    = [aws_eip.bastion-eip.public_ip]
}
*/
