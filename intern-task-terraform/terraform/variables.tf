variable "aws_region" {
  description = "AWS region for the infrastructure"
  type        = string
  default     = "us-east-1"
}

variable "ssh_cidr" {
  description = "IPv4 CIDR allowed to connect over SSH"
  type        = string

  validation {
    condition     = try(cidrnetmask(var.ssh_cidr) != "0.0.0.0", false)
    error_message = "Provide a valid IPv4 CIDR narrower than /0."
  }
}

variable "ami_id" {
  description = "Ubuntu AMI ID for the selected AWS region"
  type        = string
  default     = "ami-0e2c8caa4b6378d8c"
}

variable "instance_type" {
  description = "EC2 instance size"
  type        = string
  default     = "t3.micro"
}