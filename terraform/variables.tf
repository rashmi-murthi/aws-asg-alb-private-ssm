variable "region" {
  type        = string
  description = "AWS region"
}
variable "cidr_block" {
  type        = string
  description = "VPC CIDR block"
  default     = "10.0.0.0/16"
}
variable "public_subnet1_cidr" {
  type    = string
  default = "10.0.1.0/24"
}
variable "public_subnet2_cidr" {
  type    = string
  default = "10.0.2.0/24"
}
variable "private_subnet1_cidr" {
  type    = string
  default = "10.0.3.0/24"
}
variable "private_subnet2_cidr" {
  type    = string
  default = "10.0.4.0/24"
}
variable "ami_id" {
  type        = string
  description = "AMI ID for launch template (Ubuntu recommended)"
}
variable "instance_type" {
  type        = string
  description = "EC2 instance type for ASG"
  default     = "t2.micro"
}
variable "asg_min_size" {
  type    = number
  default = 2
}
variable "asg_max_size" {
  type    = number
  default = 5
}

variable "asg_desired_capacity" {
  type    = number
  default = 2
}