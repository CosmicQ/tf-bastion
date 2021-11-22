# Security Group ID
output "bastion_sg_id" {
  description = "The security group of the bastion host."
  value       = "${module.bastion_sg.security_group_id}"
}

# Elastic ID
output "bastion_eip_id" {
  description = "The elastic IP ID"
  value       = "${aws_eip.bastion-eip.id}"
}

# Elastic IP
output "bastion_eip_ip" {
  description = "The IP address of the Bastion EIP"
  value       = "${aws_eip.bastion-eip.public_ip}"
}

# Elastic DNS
output "bastion_eip_dns" {
  description = "The DNS of the Bastion EIP"
  value       = "${aws_eip.bastion-eip.public_dns}
}