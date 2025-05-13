variable "region" {
  description = "AWS region for resources"
  type        = string
}

variable "vpc_cidr" {
  description = "IP address for VPC"
  type        = string
}

variable "public_subnets" {
  type        = list(string)
  description = "Public subnets for VPC"
}

variable "private_subnets" {
  type        = list(string)
  description = "Private subnets for VPC"
}

variable "instance_type" {
  description = "AWS EC2 instance type"
  type        = string
}
