# Security Group ID
output "bastion_sg_id" {
  description = "The security group of the bastion host."
  value       = "${module.bastion_sg.this_security_group_id}"
}

# Elastic IP
output "bastion_eip_id" {
  description = "The elastic IP of the bastion host."
  value       = "${aws_eip.bastion-eip.id}"
}