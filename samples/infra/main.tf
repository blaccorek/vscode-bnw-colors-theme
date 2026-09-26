# Sample Terraform: providers, variables, locals, resources, modules, loops.
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6"
    }
  }

  backend "s3" {
    bucket         = "bnw-tfstate"
    key            = "envs/prod/terraform.tfstate"
    region         = "eu-west-3"
    dynamodb_table = "bnw-tflock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = local.common_tags
  }
}

variable "region" {
  type        = string
  description = "AWS region to deploy into."
  default     = "eu-west-3"
}

variable "environment" {
  type        = string
  description = "Deployment environment."

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of dev, staging, prod."
  }
}

variable "instance_types" {
  type    = list(string)
  default = ["t3.small", "t3.medium"]
}

variable "node_groups" {
  type = map(object({
    min_size      = number
    max_size      = number
    desired_size  = number
    capacity_type = optional(string, "ON_DEMAND")
    labels        = optional(map(string), {})
  }))
  default = {
    general = { min_size = 2, max_size = 6, desired_size = 3 }
    spot    = { min_size = 0, max_size = 10, desired_size = 2, capacity_type = "SPOT" }
  }
}

locals {
  name_prefix = "bnw-${var.environment}"
  is_prod     = var.environment == "prod"
  azs         = slice(data.aws_availability_zones.available.names, 0, 3)

  common_tags = {
    Project     = "bnw-colors"
    Environment = var.environment
    ManagedBy   = "terraform"
    CostCenter  = local.is_prod ? "prod-1000" : "sandbox-0"
  }

  subnet_cidrs = { for idx, az in local.azs : az => cidrsubnet("10.0.0.0/16", 4, idx) }
}

data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

data "aws_caller_identity" "current" {}

resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-vpc" })
}

resource "aws_subnet" "private" {
  for_each = local.subnet_cidrs

  vpc_id            = aws_vpc.main.id
  availability_zone = each.key
  cidr_block        = each.value

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-private-${each.key}"
    Tier = "private"
  })
}

resource "aws_s3_bucket" "artifacts" {
  bucket        = lower("${local.name_prefix}-artifacts-${random_id.suffix.hex}")
  force_destroy = !local.is_prod
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  versioning_configuration {
    status = local.is_prod ? "Enabled" : "Suspended"
  }
}

resource "aws_iam_role" "app" {
  name = "${local.name_prefix}-app"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRole"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        }
      }
    }]
  })

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [tags["LastRotated"]]
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.8"

  cluster_name    = "${local.name_prefix}-eks"
  cluster_version = "1.29"
  vpc_id          = aws_vpc.main.id
  subnet_ids      = [for s in aws_subnet.private : s.id]

  eks_managed_node_groups = {
    for name, cfg in var.node_groups : name => {
      min_size       = cfg.min_size
      max_size       = cfg.max_size
      desired_size   = cfg.desired_size
      capacity_type  = cfg.capacity_type
      instance_types = var.instance_types
      labels         = merge({ "node.kubernetes.io/pool" = name }, cfg.labels)
    }
  }

  depends_on = [aws_vpc.main]
}

output "vpc_id" {
  value = aws_vpc.main.id
}

output "bucket_arn" {
  description = "ARN of the artifacts bucket."
  value       = aws_s3_bucket.artifacts.arn
  sensitive   = false
}

output "subnet_map" {
  value = { for az, subnet in aws_subnet.private : az => subnet.cidr_block }
}
