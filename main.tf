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
  default = "../files/bastion_userdata.sh"
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

data "template_cloudinit_config" "userdata" {
  part {
    content = <<EOF
#!/bin/bash
yum -y update && yum -y install awscli aws-cfn-bootstrap ruby wget

cd /home/ec2-user
wget https://aws-codedeploy-", { "Ref": "AWS::Region" }, ".s3.amazonaws.com/latest/install
chmod +x ./install
sudo ./install auto

NUM=`curl -s http://169.254.169.254/latest/meta-data/local-ipv4 |awk -F. '{print $3\"-\"$4}'` && sed -i \"s/HOSTNAME=localhost.localdomain/HOSTNAME=", {"Ref": "Hostname"}, "-$NUM/\" /etc/sysconfig/network && hostname ", {"Ref": "Hostname"}, "-$NUM"

aws --region ", {"Ref": "AWS::Region"}, " ec2 disassociate-address --association-id `aws --output text --region ", {"Ref": "AWS::Region"}, " ec2 describe-addresses |grep ", {"Ref": "bastionEip"}, " |awk {'print $3'}`

aws --region ", {"Ref": "AWS::Region"}, " ec2 associate-address --instance-id `curl http://169.254.169.254/latest/meta-data/instance-id` --allocation-id ", {"Fn::GetAtt": ["bastionEip", "AllocationId"]}, 

cat <<'EOC'>> /var/spool/cron/root
*/10 * * * * echo -e '127.0.0.1\tlocalhost localhost.localdomain' > /etc/hosts && /usr/bin/aws ec2 describe-instances --region ", "Ref": "AWS::Region" },
 --filters Name=instance-state-name,Values=running --query 'Reservations[].Instances[].[PrivateIpAddress,Tags[?Key==`Name`].Value[]]' --output text | sed '$!N;s/\\n/\\t/' |sort -n -t . -k 1,1 -k 2,2 -k 3,3 -k 4,4 >> /etc/hosts

0 23 * * * yum -y update --security --exclude=kernel* > /dev/null 2>&1
EOC

/opt/aws/bin/cfn-signal -e $?
         --stack ", { "Ref": "AWS::StackName" },
         --resource bastionAutoScalingGroup ",
         --region ", { "Ref": "AWS::Region" },
EOF

##########################################################
# Create the Bastion server
resource "aws_eip" "bastion-eip" {
  instance = "${aws_instance.bastion.id}"
  vpc      = true
  instance = "${module.ec2.id[0]}"

  tags = {
    CreatedBy   = "CosmicQ"
    Terraform   = "true"
    Environment = "${var.env}"
    Workspace   = "${terraform.workspace}"
  }

}



