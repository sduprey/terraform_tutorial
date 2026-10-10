output "vpc_id" {
  value = aws_vpc.main.id
}

output "subnet_ids" {
  description = "Map clé -> id du sous-réseau"
  value       = { for k, s in aws_subnet.this : k => s.id }
}

output "web_sg_id" {
  value = aws_security_group.web.id
}
