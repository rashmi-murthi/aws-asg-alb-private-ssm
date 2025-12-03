output "alb_dns_name" {
  description = "Application Load Balancer DNS name"
  value       = aws_lb.alb_public.dns_name
}

output "vpc_id" {
  value = aws_vpc.demo_vpc.id
}

output "private_subnets" {
  value = [aws_subnet.private_subnet1.id, aws_subnet.private_subnet2.id]
}

output "public_subnets" {
  value = [aws_subnet.public_subnet1.id, aws_subnet.public_subnet2.id]
}
