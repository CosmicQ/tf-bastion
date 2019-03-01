#!/bin/bash
# The echo statements are here to help debug what is going on.  To see results
# look at /var/log/cloud-init-output.log when the instance is up.

#update
echo "### Getting update and installing aws-cli"
yum update -y && yum install -y aws-cli
echo "### Installing Cloudwatch agent"
rpm -Uvh https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm

# Set vars
echo "### Declaring variables"
declare -rx REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/[a-z]$//')
declare -rx NUM=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4 |awk -F. '{print $3"-"$4}')
declare -rx INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
declare -rx NAME=$(aws --region $REGION ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[].Instances[].Tags[?Key==`Name`].Value' --output text)
declare -rx ENVIRONMENT=$(aws --region $REGION ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[].Instances[].Tags[?Key==`Environment`].Value' --output text)
declare -rx S3_BUCKET_NAME=$(aws --region $REGION ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[].Instances[].Tags[?Key==`s3_bucket_name`].Value' --output text)
# For Instances that need Elastic IP addresses
declare -rx ASSOCIATION_ID=$(aws --region $REGION ec2 describe-addresses --query 'Addresses[].AssociationId[]' --filters "Name=tag:bastion,Values=true" --output text)
declare -rx ALLOCATION_ID=$(aws --region $REGION ec2 describe-addresses --query 'Addresses[].AllocationId[]' --filters "Name=tag:bastion,Values=true" --output text)

#set hostname
echo "### Setting hostname"
sed -i "s/HOSTNAME=localhost.localdomain/HOSTNAME=${NAME}-${NUM}/" /etc/sysconfig/network
hostname $NAME-$NUM

# Detach EIP from any other instance and attach to this instance
echo "### Doing EIP Magic"
aws --region $REGION ec2 disassociate-address --association-id $ASSOCIATION_ID
aws --region $REGION ec2 associate-address --instance-id $INSTANCE_ID --allocation-id $ALLOCATION_ID 

# Keep the SSH_CLIENT environment variable
echo "### Adding lines to /etc/sudoers"
echo "Defaults env_keep += \"SSH_CLIENT\"" >> /etc/sudoers

# Send commands to /var/log/commands
echo "### Adding lines to /etc/bashrc"
cat <<'EOC'>> /etc/bashrc
export SSH_CLIENT=${SSH_CLIENT}
declare -rx IP=$(echo $SSH_CLIENT | awk '{print $1}')
declare -rx BASTION_LOG=/var/log/commands
declare -rx PROMPT_COMMAND='history -a >(logger -t "ON: $(date)   [FROM]:${IP}   [USER]:${USER}   [PWD]:${PWD}" -s 2>>${BASTION_LOG})'
EOC

# Creating /var/log/commands
echo "### Creating /var/log/commands and setting permissions"
touch /var/log/commands
chmod 662 /var/log/commands

# Send log files to cloudwatch logs
if [ -e /opt/aws/amazon-cloudwatch-agent/etc ]&&[ ! -f /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json ]; then
  echo "### Cloudwatch agent is installed, configure and start it"
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
                        "log_stream_name": "{ip_address}-{instance_id}",
                        "timestamp_format": "%Y-%m-%d %H:%M:%S",
                        "timezone": "UTC"
                    },
                    {
                        "file_path": "/var/log/secure",
                        "log_group_name": "/var/log/secure",
                        "log_stream_name": "{ip_address}-{instance_id}",
                        "timestamp_format": "%Y-%m-%d %H:%M:%S",
                        "timezone": "UTC"
                    },
                    {
                        "file_path": "/var/log/messages",
                        "log_group_name": "/var/log/messages",
                        "log_stream_name": "{ip_address}-{instance_id}",
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
fi

# If we have a SSH host ID alredy established, let's use that
echo "### Establishing SSH host ID"
if [ ! $(aws s3 ls q-test-bastion/sshd/ssh_host_ecdsa_key) ]; then
  # Host identity has not been established.  Use this hosts identity as the baseline
  aws s3 cp /etc/ssh/ssh_host_ecdsa_key s3://$S3_BUCKET_NAME/sshd/ssh_host_ecdsa_key
  aws s3 cp /etc/ssh/ssh_host_ecdsa_key.pub s3://$S3_BUCKET_NAME/sshd/ssh_host_ecdsa_key.pub
  aws s3 cp /etc/ssh/ssh_host_ed25519_key s3://$S3_BUCKET_NAME/sshd/ssh_host_ed25519_key
  aws s3 cp /etc/ssh/ssh_host_ed25519_key.pub s3://$S3_BUCKET_NAME/sshd/ssh_host_ed25519_key.pub
  aws s3 cp /etc/ssh/ssh_host_rsa_key s3://$S3_BUCKET_NAME/sshd/ssh_host_rsa_key
  aws s3 cp /etc/ssh/ssh_host_rsa_key.pub s3://$S3_BUCKET_NAME/sshd/ssh_host_rsa_key.pub
else
  # The host id was already established.  Copy it over and restart ssh
  aws s3 cp s3://$S3_BUCKET_NAME/sshd/ssh_host_ecdsa_key /etc/ssh/ssh_host_ecdsa_key
  aws s3 cp s3://$S3_BUCKET_NAME/sshd/ssh_host_ecdsa_key.pub /etc/ssh/ssh_host_ecdsa_key.pub
  aws s3 cp s3://$S3_BUCKET_NAME/sshd/ssh_host_ed25519_key /etc/ssh/ssh_host_ed25519_key
  aws s3 cp s3://$S3_BUCKET_NAME/sshd/ssh_host_ed25519_key.pub /etc/ssh/ssh_host_ed25519_key.pub
  aws s3 cp s3://$S3_BUCKET_NAME/sshd/ssh_host_rsa_key /etc/ssh/ssh_host_rsa_key
  aws s3 cp s3://$S3_BUCKET_NAME/sshd/ssh_host_rsa_key.pub /etc/ssh/ssh_host_rsa_key.pub

  chmod 600 /etc/ssh/ssh_host_*

  if [ -x /bin/systemctl ] || [ -x /usr/bin/systemctl ]; then
    systemctl restart sshd.service
  fi
fi

# Copy over any public keys that were added to s3://bastion-bucket/keys/
echo "### Adding keys from $S3_BUCKET_NAME/keys/"
aws s3 ls $S3_BUCKET_NAME/keys/ | while read line; do
  file=$(echo $line | awk '{print $4}')
  if [[ "${file}" =~ .pub$ ]]; then
    echo "# adding s3://$S3_BUCKET_NAME/keys/$file"
    key=$(aws s3 cp --quiet s3://$S3_BUCKET_NAME/keys/$file /dev/stdout)
    echo $key >> ~ec2-user/.ssh/authorized_keys
  fi
done

# Add cron.  Do security updates, but no kernel updates since those require a reboot
echo "### Updating root cron"
cat <<'EOC'>> /var/spool/cron/root
*/10 * * * * echo -e '127.0.0.1\tlocalhost localhost.localdomain' > /etc/hosts && /usr/bin/aws ec2 describe-instances --region ", "Ref": "AWS::Region" },
 --filters Name=instance-state-name,Values=running --query 'Reservations[].Instances[].[PrivateIpAddress,Tags[?Key==`Name`].Value[]]' --output text | sed '$!N;s/\\n/\\t/' |sort -n -t . -k 1,1 -k 2,2 -k 3,3 -k 4,4 >> /etc/hosts

0 23 * * * yum -y update --security --exclude=kernel* > /dev/null 2>&1
EOC