# -----------------------------------------------------------------------------
# ENVIRONMENT VARIABLES
# Define these secrets as environment variables
# -----------------------------------------------------------------------------

# AWS_ACCESS_KEY_ID
# AWS_SECRET_ACCESS_KEY


# -----------------------------------------------------------------------------
# AWS SSM PARAMETERS
# The secrets need to be defined in the AWS SSM Parameter Store
# before running terraform.
# -----------------------------------------------------------------------------

#/${var.project_name}/${var.stage}/hasura_admin_secret
#/${var.project_name}/${var.stage}/hasura_db_password


# -----------------------------------------------------------------------------
# PARAMETERS
# -----------------------------------------------------------------------------
variable "project_name" {
  description = "Project name which will be part of resource identifiers."
  default     = "demo-apps"
}

variable "app_name" {
  description = "Project name which will be part of resource identifiers."
  default     = "mydashboard"
}

variable "stage" {
  description = "Stage e.g. staging, production that will be part of resource identifiers."
}


variable "region" {
  description = "Region to deploy"
  default     = "eu-central-1"
}

variable "domain" {
  description = "Domain name. Service will be deployed in the domain's route53 zone using the app's subdomain"
}

variable "app_subdomain" {
  description = "The subdomain where the app is publicly available."
  default     = "cms"
}

variable "app_health_check_path" {
  description = "The endpoint of the app that is used for health checks by the load balancer."
  default     = "/"
}

variable "vpc_id" {
  description = "VPC ID to deploy the app in."
}

variable "public_subnets" {
  description = "Public subnets in the VPC to spawn the load balancer in."
}

variable "private_subnets" {
  description = "Private subnets in the VPC to spawn the containers in."
}


variable "app_image" {
  description = "The app's image tag"
  default     = "ghcr.io/canida-software/website-strapi:latest"
}

variable "registry_secret_arn" {
  description = "ARN to a secret in AWS Secrets Manager containing the credentials to access the app's image repository. The secret must contain the following keys: username, password. E.g. { username = \"foo\", password = \"bar\" }"
  default     = ""
}

variable "app_port" {
  description = "The IP that the app listens to for new connections."
  default     = "8080"
}

variable "multi_az" {
  description = "Whether to deploy RDS and ECS in multi AZ mode or not"
  default     = true
}

variable "app_environment" {
  description = "Environment variables for ECS task: [ { name = \"foo\", value = \"bar\" }, ..]"
  default     = []
}

variable "default_tags" {
  description = "Default tags to apply to all resources"
  default     = {}
}

variable "create_iam_service_linked_role" {
  description = "Whether to create IAM service linked role for AWS ECS service. Can be only one per AWS account."
  default     = true
}
