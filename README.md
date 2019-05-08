# tf-bastion
Bastion host module for Terraform

## Overview
This bastion module creates a bastion server on a (preferably) public subnet.

This module will create the following resources:
* Elastic IP address
* S3 bucket
* EC2 instance
* Auto-scaling group and launch config
* 2 Cloudwatch log groups
* (optional) DNS record

## Usage example

An example of how to use the bastion module

```hcl
module "bastion" {
  source               = "github.com/CosmicQ/tf-bastion"
  version              = "v0.1.0"

  vpc_id               = "${module.vpc.vpc_id}"
  public_subnets       = ["${module.vpc.public_subnets}"]

  bastion_ingress      = ["1.2.3.4/32"]
  bastion_key_name     = "my_key"
  bastion_user_data    = "${path.module}files/bastion_userdata.sh"
  bastion_s3_bucket    = "mydomain-bastion"
  bastion_name         = "bastion"

  create_bastion_dns   = true
  bastion_domain      = "mydomain.com"
}
```
## Details

Terraform will create an elastic IP address for the bastion server to use.  A userdata script will 
Locate the EIP, remove it from another instances if it is still attached, and then attach the EIP 
to the bastion instance.

S3 is used to store the host identity, and to load public keys into the ec2-user authorized_keys file. 
To add keys to the bastion server, just upload a public key to the bastion s3 bucket with a 'keys' prefix.
```
 s3://my_bastion_s3_bucket/keys/someuser.pub
```
The userdata script will iterate over each .pub file in this directory and append them to the `ec2-user` 
authorized_keys file.  Just terminate the bastion instance after you drop in the keys and it will re-build 
itself with the added keys.

The bastion host will install the cloudwatch agent and configure it to send `/var/log/secure` and 
`/var/log/commands` to log groups.  Commands are simply the bash history sent to cloudwatch as each command is 
typed.

DNS for your bastion host is an optional function.  Just set the `create_bastion_dns` var to true, and fill 
in the domain for `bastion_dns`.  This module will use `${var.bastion_name}.${var.bastion_domain}` to create 
the host record.

NOTE: For 'bastion_user_data' you can use the default as listed above in the example, or provide your own userdata script.

## Inputs
```
             source - required
            version - optional
             vpc_id - required
     public_subnets - required
    bastion_ingress - optional (default allow 0.0.0.0/0 ingress)
   bastion_key_name - optional
  bastion_user_data - required
  bastion_s3_bucket - required
       bastion_name - required
 create_bastion_dns - required
     bastion_domain - optional
```

## Outputs
```
 bastion_sg_id  - ID of the security group that gets created
 bastion_eip_id - ID of the elastic IP that gets created
```