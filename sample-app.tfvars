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
vpc_id          = "vpc-0837d9345e6b3c7fc"

# -----------------------------------------------------------------------------
# Public subnets to spawn the load balancer in and private subnets to spawn your container in.
# If your VPC only contains public subnets, then you can also use them for the private subnets. 
# However, for production it is recommended to use private subnets.
# -----------------------------------------------------------------------------
private_subnets = ["subnet-0b71c2093592fad11", "subnet-098d9f8f7cd6e8718", "subnet-037daf351c7c38c13"]
public_subnets  = ["subnet-00070c45e086b1b11", "subnet-0cbc61d04f319354b", "subnet-02364497a08b776ae"]

environment = [
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


