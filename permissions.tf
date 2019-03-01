# Bastion security group
module "bastion_sg" {
  source                       = "terraform-aws-modules/security-group/aws//modules/ssh"
  name                         = "bastion_sg"
  description                  = "Allow traffic to Bastion"
  vpc_id                       = "${var.vpc_id}"
  ingress_cidr_blocks          = "${var.bastion_ingress}"
  tags     = {
    Name        = "BastionSG"
    Terraform   = "true"
    Workspace   = "${terraform.workspace}"
  }
}

resource "aws_cloudwatch_log_group" "messages_lg" {
  name = "/var/log/messages"
}

resource "aws_cloudwatch_log_group" "secure_lg" {
  name = "/var/log/secure"
}

resource "aws_cloudwatch_log_group" "commands_lg" {
  name = "/var/log/commands"
}

resource "aws_iam_role" "bastion_role" {
  name = "bastion_role"
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
  name        = "bastion-policy"
  description = "A set of permissions for a Bastion host"
  policy      = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
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
                "tag:GetTagKeys",
                "s3:*"
            ],
            "Resource": "*"
        },
        {
            "Sid": "VisualEditor1",
            "Effect": "Allow",
            "Action": [
                "logs:GetLogEvents",
                "logs:PutLogEvents"
            ],
            "Resource": "arn:aws:logs:*:*:log-group:*:*:*"
        },
        {
            "Sid": "VisualEditor2",
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
  name = "bastion_profile"
  role = "${aws_iam_role.bastion_role.name}"
}

resource "aws_iam_policy_attachment" "bastion-attach" {
  name       = "bastion-attachment"
  roles      = ["${aws_iam_role.bastion_role.name}"]
  policy_arn = "${aws_iam_policy.policy.arn}"
}
