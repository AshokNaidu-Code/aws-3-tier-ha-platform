variable "project_name" {
  description = "Project name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for EC2 instances"
  type        = list(string)
}

variable "alb_sg_id" {
  description = "Security group ID of ALB"
  type        = string
}

variable "app_sg_id" {
  description = "Security group ID for app instances (created in root module)"
  type        = string
}

variable "target_group_arn" {
  description = "Target group ARN"
  type        = string
}

variable "ami_id" {
  description = "AMI ID for EC2 instances"
  type        = string
}

variable "instance_type" {
  description = "Instance type"
  type        = string
  default     = "t3.micro"
}

variable "min_size" {
  description = "Minimum number of instances"
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum number of instances"
  type        = number
  default     = 4
}

variable "desired_capacity" {
  description = "Desired number of instances"
  type        = number
  default     = 2
}

variable "user_data_path" {
  description = "Path to user data script"
  type        = string
}

variable "rds_endpoint" {
  description = "RDS endpoint"
  type        = string
}

variable "rds_user" {
  description = "RDS username"
  type        = string
}

variable "rds_password" {
  description = "RDS password"
  type        = string
  sensitive   = true
}

variable "rds_db" {
  description = "RDS database name"
  type        = string
}
