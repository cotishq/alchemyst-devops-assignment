variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "project" {
  description = "Project name prefix"
  type        = string
  default     = "alchemyst"
}

variable "key_name" {
  description = "AWS key pair name"
  type        = string
}

variable "your_ip" {
  description = "Your IP in CIDR notation for SSH access"
  type        = string
}
