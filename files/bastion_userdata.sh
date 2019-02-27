#!/bin/bash

#update
yum update -y && yum install -y aws-cli wget amazon-cloudwatch-agent awslogs

# Set vars
REGION=`curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/[a-z]$//'`
NUM=`curl -s http://169.254.169.254/latest/meta-data/local-ipv4 |awk -F. '{print $3"-"$4}'`
INSTANCE_ID=`curl -s http://169.254.169.254/latest/meta-data/instance-id`
NAME=`aws ec2 describe-instances --region $REGION --instance-ids $INSTANCE_ID --query 'Reservations[].Instances[].Tags[?Key==\`Name\`].Value' --output text`
ENVIRONMENT=`aws ec2 describe-instances --region $REGION --instance-ids $INSTANCE_ID --query 'Reservations[].Instances[].Tags[?Key==\`Environment\`].Value' --output text`

#set hostname
sed -i "s/HOSTNAME=localhost.localdomain/HOSTNAME=${NAME}-${NUM}/" /etc/sysconfig/network
hostname $NAME-$NUM

#rpm -Uvh https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
#/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c ssm:AmazonCloudWatch -s

ASSOCIATION_ID=`aws --region $REGION ec2 describe-addresses --query 'Addresses[].AssociationId[]' --filters "Name=tag:Name,Values=BastionEIP" --output text`
ALLOCATION_ID=`aws --region $REGION ec2 describe-addresses --query 'Addresses[].AllocationId[]' --filters "Name=tag:Name,Values=BastionEIP" --output text`

aws --region $REGION ec2 disassociate-address --association-id $ASSOCIATION_ID
aws --region $REGION ec2 associate-address --instance-id $INSTANCE_ID --allocation-id $ALLOCATION_ID 

cat <<'EOC'>> /var/spool/cron/root
*/10 * * * * echo -e '127.0.0.1\tlocalhost localhost.localdomain' > /etc/hosts && /usr/bin/aws ec2 describe-instances --region ", "Ref": "AWS::Region" },
 --filters Name=instance-state-name,Values=running --query 'Reservations[].Instances[].[PrivateIpAddress,Tags[?Key==`Name`].Value[]]' --output text | sed '$!N;s/\\n/\\t/' |sort -n -t . -k 1,1 -k 2,2 -k 3,3 -k 4,4 >> /etc/hosts

0 23 * * * yum -y update --security --exclude=kernel* > /dev/null 2>&1
EOC