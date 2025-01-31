variable "aws_access_key" {
  description = "AWS Access Key"
  type        = string
}

variable "aws_secret_key" {
  description = "AWS Secret Key"
  type        = string
}

variable "aws_session_token" {
  description = "AWS Session Token"
  type        = string
}

variable "region" {
  description = "AWS Region"
  type        = string
  default = "us-east-1"
}

variable "vpc_cidr" {
  description = "VPC CIDR Block"
  type        = string
  default = "10.0.0.0/16"
}