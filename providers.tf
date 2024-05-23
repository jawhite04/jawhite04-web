terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    key     = "jawhite04-web/terraform.tfstate"
    region  = "us-east-1"
    profile = "com-jawhite04"
  }
}

provider "aws" {
  region  = "us-east-1"
  profile = "com-jawhite04"
}

provider "aws" {
  alias   = "route53"
  region  = "us-east-1"
  profile = "route53-contributor"
}