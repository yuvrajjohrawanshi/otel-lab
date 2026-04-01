variable "aws_region" {
  description = "AWS region to deploy resources in"
  type        = string
  default     = "us-east-1"
}

variable "admin_cidr" {
  description = "Your public IP in CIDR notation for SSH access (e.g. 203.0.113.5/32). Get it via: curl ifconfig.me"
  type        = string
  # No default — must be set explicitly to avoid wide-open SSH
}

variable "activegate_instance_type" {
  description = "EC2 instance type for the Dynatrace ActiveGate VM (min: 2 vCPU / 4GB RAM)"
  type        = string
  default     = "t3.medium"  # 2 vCPU / 4GB RAM
}

variable "app_instance_type" {
  description = "EC2 instance type for the App VM (OTel Agent + Collector + Node.js)"
  type        = string
  default     = "t3.small"   # 2 vCPU / 2GB RAM
}

variable "vpc_cidr" {
  description = "CIDR block for the lab VPC"
  type        = string
  default     = "10.10.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.10.1.0/24"
}

variable "project_name" {
  description = "Tag prefix applied to all resources — useful for identifying lab resources in the console"
  type        = string
  default     = "otel-lab2"
}
