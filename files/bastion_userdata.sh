#!/bin/bash

#update
yum update -y && yum install -y aws-cli

# Set vars
declare -rx REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/[a-z]$//')
declare -rx NUM=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4 |awk -F. '{print $3"-"$4}')
declare -rx INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
declare -rx NAME=$(aws ec2 describe-instances --region $REGION --instance-ids $INSTANCE_ID --query 'Reservations[].Instances[].Tags[?Key==`Name`].Value' --output text)
declare -rx ENVIRONMENT=$(aws ec2 describe-instances --region $REGION --instance-ids $INSTANCE_ID --query 'Reservations[].Instances[].Tags[?Key==`Environment`].Value' --output text)
# For Instances that need Elastic IP addresses
declare -rx ASSOCIATION_ID=$(aws --region $REGION ec2 describe-addresses --query 'Addresses[].AssociationId[]' --filters "Name=tag:Name,Values=BastionEIP" --output text)
declare -rx ALLOCATION_ID=$(aws --region $REGION ec2 describe-addresses --query 'Addresses[].AllocationId[]' --filters "Name=tag:Name,Values=BastionEIP" --output text)

#set hostname
sed -i "s/HOSTNAME=localhost.localdomain/HOSTNAME=${NAME}-${NUM}/" /etc/sysconfig/network
hostname $NAME-$NUM

# Detach EIP from any other instance and attach to this instance
aws --region $REGION ec2 disassociate-address --association-id $ASSOCIATION_ID
aws --region $REGION ec2 associate-address --instance-id $INSTANCE_ID --allocation-id $ALLOCATION_ID 

# Keep the SSH_CLIENT environment variable
echo "Defaults env_keep += \"SSH_CLIENT\"" >> /etc/sudoers

# Send commands to /var/log/commands
cat <<'EOC'>> /etc/bashrc
export SSH_CLIENT=${SSH_CLIENT}
declare -rx IP=$(echo $SSH_CLIENT | awk '{print $1}')
declare -rx BASTION_LOG=/var/log/commands
declare -rx PROMPT_COMMAND='history -a >(logger -t "ON: $(date)   [FROM]:${IP}   [USER]:${USER}   [PWD]:${PWD}" -s 2>>${BASTION_LOG})'
EOC

touch /var/log/commands
chmod 662 /var/log/commands

rpm -Uvh https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm

# Send log files to cloudwatch logs
cat <<EOF >> /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
{
    "logs": {
        "force_flush_interval": 5,
        "logs_collected": {
            "files": {
                "collect_list": [
                    {
                        "file_path": "/var/log/commands",
                        "log_group_name": "/var/log/commands",
                        "log_stream_name": "{hostname}-{instance_id}",
                        "timestamp_format": "%Y-%m-%d %H:%M:%S",
                        "timezone": "UTC"
                    },
                    {
                        "file_path": "/var/log/secure",
                        "log_group_name": "/var/log/secure",
                        "log_stream_name": "{hostname}-{instance_id}",
                        "timestamp_format": "%Y-%m-%d %H:%M:%S",
                        "timezone": "UTC"
                    },
                    {
                        "file_path": "/var/log/messages",
                        "log_group_name": "/var/log/messages",
                        "log_stream_name": "{hostname}-{instance_id}",
                        "timestamp_format": "%Y-%m-%d %H:%M:%S",
                        "timezone": "UTC"
                    }                                        
                ]
            }
        }
    }
}
EOF

if [ -x /bin/systemctl ] || [ -x /usr/bin/systemctl ]; then
  systemctl enable amazon-cloudwatch-agent.service
  systemctl restart amazon-cloudwatch-agent.service
else
  start amazon-cloudwatch-agent
fi

# Add cron.  Do security updates, but no kernel updates since those require a reboot
cat <<'EOC'>> /var/spool/cron/root
*/10 * * * * echo -e '127.0.0.1\tlocalhost localhost.localdomain' > /etc/hosts && /usr/bin/aws ec2 describe-instances --region ", "Ref": "AWS::Region" },
 --filters Name=instance-state-name,Values=running --query 'Reservations[].Instances[].[PrivateIpAddress,Tags[?Key==`Name`].Value[]]' --output text | sed '$!N;s/\\n/\\t/' |sort -n -t . -k 1,1 -k 2,2 -k 3,3 -k 4,4 >> /etc/hosts

0 23 * * * yum -y update --security --exclude=kernel* > /dev/null 2>&1
EOC