terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# 1. VPC Module - No dependencies
module "vpc" {
  source = "../../modules/vpc"

  project_name             = var.project_name
  vpc_cidr                 = var.vpc_cidr
  public_subnet_cidrs      = var.public_subnet_cidrs
  private_app_subnet_cidrs = var.private_app_subnet_cidrs
  private_db_subnet_cidrs  = var.private_db_subnet_cidrs
  availability_zones       = var.availability_zones
}

# 2. ALB Module - Depends only on VPC
module "alb" {
  source = "../../modules/alb"

  project_name      = var.project_name
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
}

# 3. Create App Security Group (FIRST - before compute and database)
resource "aws_security_group" "app" {
  name        = "${var.project_name}-app-sg"
  description = "Security group for application instances"
  vpc_id      = module.vpc.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name = "${var.project_name}-app-sg"
  }
}

# 4. Add ALB to App SG ingress rule
resource "aws_security_group_rule" "app_from_alb" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = module.alb.alb_sg_id
  security_group_id        = aws_security_group.app.id
  description              = "Allow HTTP from ALB"
}

# 5. Compute Module - Depends on VPC and ALB (gets app_sg_id from resource)
module "compute" {
  source = "../../modules/compute"

  project_name       = var.project_name
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_app_subnet_ids
  alb_sg_id          = module.alb.alb_sg_id
  target_group_arn   = module.alb.target_group_arn
  app_sg_id          = aws_security_group.app.id # Use created resource, not module output
  ami_id             = var.ami_id
  instance_type      = var.instance_type
  min_size           = var.min_size
  max_size           = var.max_size
  desired_capacity   = var.desired_capacity
  user_data_path     = "../../services/user_data.sh"
  rds_endpoint       = module.database.rds_endpoint
  rds_user           = var.db_username
  rds_password       = var.db_password
  rds_db             = var.db_name
}

# 6. Database Module - Depends only on VPC and app security group (NO dependency on compute module)
module "database" {
  source = "../../modules/database"

  project_name          = var.project_name
  vpc_id                = module.vpc.vpc_id
  private_db_subnet_ids = module.vpc.private_db_subnet_ids
  app_sg_id             = aws_security_group.app.id # Use created resource
  db_name               = var.db_name
  db_username           = var.db_username
  db_password           = var.db_password
}
