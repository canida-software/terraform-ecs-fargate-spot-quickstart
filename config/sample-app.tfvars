# -----------------------------------------------------------------------------
# App Configuration
#
# See variables.tf for descriptions of the fields.
# -----------------------------------------------------------------------------

region          = "eu-central-1"
project_name    = "demos"
app_name        = "sample-app"
stage           = "production"
domain          = "canida.io"
app_subdomain   = "sample-app"
vpc_id          = "vpc-XXX"

# -----------------------------------------------------------------------------
# Public subnets to spawn the load balancer in and private subnets to spawn your container in.
# If your VPC only contains public subnets, then you can also use them for the private subnets. 
# However, for production it is recommended to use private subnets.
# -----------------------------------------------------------------------------
private_subnets = ["subnet-XXX", "subnet-XXX", "subnet-XXX"]
public_subnets  = ["subnet-XXX", "subnet-XXX", "subnet-XXX"]


# -----------------------------------------------------------------------------
# Add your own environment variables here. They will be available in your container.
# -----------------------------------------------------------------------------
app_environment = [
  {
    name  = "KEY",
    value = "VALUE"
  }
]
app_health_check_path = "/"
app_port            = 80
app_image           = "nginx:alpine"
registry_secret_arn = ""
multi_az            = true

default_tags = {
  "app"     = "sample-app"
  "fqdn"    = "sample-app.canida.io"
  "project" = "demos"
  "stage"   = "production"
}

# -----------------------------------------------------------------------------
# AWS requires a service linked role for this setup to work properly. 
# This role has to be created once per AWS account. If you worked with ECS before it might already exist.
# Enable this only if Terraform fails because the service linked role does not exist yet. 
# -----------------------------------------------------------------------------
create_iam_service_linked_role = false


