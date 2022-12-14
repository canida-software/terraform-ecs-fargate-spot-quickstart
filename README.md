# Deploy your containerized application to AWS ECS in 10 minutes using Terraform
This quickstart guide helps you to quickly run a containerized application on AWS. For startups/smaller projects the setup is production ready and easily extensible to fit more advanced needs. All the required resources can be created in a single command by using Terraform. The final setup is depicted below.

<p align="center">
<img src="https://github.com/canida-software/terraform-ecs-fargate-spot-quickstart/raw/main/images/overview.jpg" width="60%">
</p>

## What you will get.
- An application that runs on https://sample-app.your-domain.com.
- TLS encryption i.e. https works. 
- Optional hosting in 2 AZ's for maximum reliability.
- Low price setup by utilizing spot instances.

## What you need to bring.
- Git Repository Clone: [terraform-ecs-fargate-spot-quickstart](https://github.com/canida-software/terraform-ecs-fargate-spot-quickstart.git).
- Your Containerized Application
- Terraform Installation
- AWS CLI v2 Installation
- A domain on AWS
    - Alternatively, you can also just create a DNS zone delegation to manage subdomain.your-domain.com via AWS while leaving your-domain.com at your previous DNS provider.

## Quickstart.

### Adapt configuration values.
Check out [config/sample-app.tfvars](https://github.com/canida-software/terraform-ecs-fargate-spot-quickstart/blob/main/config/sample-app.tfvars) 
and modify the variables to serve your needs. The variables are also explained in [variables.tf](https://github.com/canida-software/terraform-ecs-fargate-spot-quickstart/blob/main/variables.tf).

### Configure State Backend
You may store the Terraform state in this git repository. To do so comment out the following section in [main.tf](https://github.com/canida-software/terraform-ecs-fargate-spot-quickstart/blob/main/main.tf) that configures s3 a remote backend.

```
terraform {
#  backend "s3" {
#    bucket = "my-terraform-bucket"
#    key    = "app.tfstate"
#    region = "eu-central-1"
#  }
}
```

If you want to use s3 to store Terraform state create a bucket as follows:

```
aws s3api create-bucket --bucket my-terraform-bucket --region eu-central-1 --create-bucket-configuration LocationConstraint=eu-central-1
```
### Initialize Terraform
```
terraform init
```

### Deploy Application

Run `terraform apply` to deploy this setup. Terraform will display the resources that will be created and you can confirm the changes. Creating the resources on AWS takes some time ~10 minutes.

```
terraform apply --var-file config/sample-app.tfvars
```

### Verify Setup
Visit `sample-app.your-domain.com` to verify that the setup worked. If you deployed the nginx image. It should look as follows:
<p align="center">
<img src="https://github.com/canida-software/terraform-ecs-fargate-spot-quickstart/raw/main/images/nginx.jpg" width="40%">
</p>

### Clean Up

```
terraform destroy --var-file config/sample-app.tfvars
```

## Extending the Setup

### Multiple Apps
You can use Terraform workspaces to manage multiple apps via this terraform module. Let's say you want to manage `sample-app1` and `sample-app2`. You can create workspaces for each app as follows:

```
terraform workspace new sample-app1
terraform workspace new sample-app2
```

and switch to a workspace using `terraform workspace select sample-app1`.

### Multiple apps in Same ECS Cluster
You can create a second ECS service to host another app. The load balancer costs ~20$ per month, therefore I recommend to share the load balancer between the apps.

### Database Access
I recommend to use a managed database created by RDS. You can just configure the database url via an environment variable.

## Additional Information

### Official AWS Quickstart Guide

AWS provides their own quickstart. However, I did not like the quality. That's why I created this setup. Check it out here: [https://github.com/aws-quickstart/terraform-aws-ecs-fargate](https://github.com/aws-quickstart/terraform-aws-ecs-fargate)


### Spot Instance Reliability
If you enable multi-az in the configuration. The app will be deployed across 2 availability zones. I.e. you won't have any downtime even if AWS kills one of your spot instances. The setup will just start another instance and in the meantime traffic is routed to your other replica only. The probability of your spot instance to get killed is <10% for a whole month. For many instances its < 5%. Check out information for specific instance types here: https://aws.amazon.com/ec2/spot/instance-advisor/

## Configuration Management using 1Password

We use 1password to store the configuration files for Terraform.

### Create new application
*Note: 1Password allows you to create the same configuration multiple times. If that happens you will have to delete one version o.w. updating the config will fail.*

```
MYAPP=sample-app
op document create --vault demo-apps config/${MYAPP}.tfvars
terraform apply --var-file ${MYAPP}.tfvars
```

### Update application

First, retrieve the latest app configuration.

```
MYAPP=sample-app
op document get --vault demo-apps ${MYAPP}.tfvars > config/${MYAPP}.tfvars
```

Then, edit the config file locally, update the documents in 1password and apply the changes via Terraform.

```
op document edit --vault demo-apps ${MYAPP}.tfvars  config/${MYAPP}.tfvars
terraform apply --var-file ${MYAPP}.tfvars
```

## Debugging Problems
A good first step is to visit ECS in the management console and check out if the tasks throw any errors.
