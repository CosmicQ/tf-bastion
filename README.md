# tf-bastion
Bastion host module for Terraform


Example
```
module "tf-bastion" {
  source               = "github.com/CosmicQ/tf-bastion"
  version              = "v0.0.1"
  vpc_id               = "vpc-xxxxxxxxxxxxx"
  public_subnets       = ["subnet-xxxxxxxxxxxxxxxa", "subnet-xxxxxxxxxxxxxxxxb"]
  bastion_key_name     = "key_bastion"
  bastion_user_data    = "modules/tf-bastion/files/bastion_userdata.sh"
  bastion_s3_bucket    = "mydomain-bastion"
}

```
