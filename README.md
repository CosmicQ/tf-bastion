# tf-bastion
Bastion host module for Terraform


Example
```
module "asg" {
  source               = "CosmicQ/tf-bastion"
  version              = "latest"
  name                 = "bastion"
}

```