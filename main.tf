provider "aws" {
  region = var.region
  default_tags {
    tags = var.default_tags
  }
}

locals {
  registry_secret_provided = var.registry_secret_arn != "" ? true : false
}

# -----------------------------------------------------------------------------
# Remote backend configuration
# Comment this out to use local backend
# -----------------------------------------------------------------------------
terraform {
  backend "s3" {
    bucket = "canida-terraform"
    key    = "ecs-app.tfstate"
    region = "eu-central-1"
  }
}

# -----------------------------------------------------------------------------
# Service role allowing AWS to manage resources required for ECS
# Only required to be created once per account.
# -----------------------------------------------------------------------------

resource "aws_iam_service_linked_role" "ecs_service" {
  aws_service_name = "ecs.amazonaws.com"
  count            = var.create_iam_service_linked_role ? 1 : 0
}


# -----------------------------------------------------------------------------
# Create security groups
# -----------------------------------------------------------------------------

# Internet to ALB
resource "aws_security_group" "app_alb" {
  name        = "${var.project_name}-${var.app_name}-${var.stage}-alb"
  description = "Allow access on port 443 to the ALB."
  vpc_id      = var.vpc_id

  ingress {
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ALB to ECS
resource "aws_security_group" "app_ecs" {
  name        = "${var.project_name}-${var.app_name}-${var.stage}-tasks"
  description = "Limit ECS access to ALB."
  vpc_id      = var.vpc_id

  ingress {
    protocol        = "tcp"
    from_port       = var.app_port
    to_port         = var.app_port
    security_groups = [aws_security_group.app_alb.id]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# -----------------------------------------------------------------------------
# Create ECS cluster
# -----------------------------------------------------------------------------

resource "aws_ecs_cluster" "app" {
  name = "${var.project_name}-${var.app_name}-${var.stage}"
}

resource "aws_ecs_cluster_capacity_providers" "app" {
  cluster_name = aws_ecs_cluster.app.name

  capacity_providers = ["FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
  }

  depends_on = [aws_ecs_cluster.app]
}

# -----------------------------------------------------------------------------
# Create logging
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.project_name}-${var.app_name}-${var.stage}"
  retention_in_days = 14
}

# -----------------------------------------------------------------------------
# Create IAM Role and attach policies 
# - for publishing logs to CloudWatch
# - for accessing the container registry
# -----------------------------------------------------------------------------


data "aws_iam_policy_document" "app_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "app_role" {
  name               = "${var.project_name}-${var.app_name}-${var.stage}"
  path               = "/system/"
  assume_role_policy = data.aws_iam_policy_document.app_assume_role_policy.json
}

data "aws_iam_policy_document" "app_log_publishing" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:PutLogEventsBatch",
    ]

    resources = ["arn:aws:logs:${var.region}:*:log-group:/ecs/${var.project_name}-${var.app_name}-${var.stage}:*"]
  }
}

resource "aws_iam_policy" "app_log_publishing" {
  name        = "${var.project_name}-${var.app_name}-${var.stage}-log-pub"
  path        = "/"
  description = "Allow publishing to cloudwach"

  policy = data.aws_iam_policy_document.app_log_publishing.json
}
resource "aws_iam_role_policy_attachment" "app_role_log_publishing" {
  role       = aws_iam_role.app_role.name
  policy_arn = aws_iam_policy.app_log_publishing.arn
}

resource "aws_iam_policy" "access_registry_secret" {
  count = local.registry_secret_provided ? 1 : 0
  name = "${var.project_name}-access-registry"

  policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": [
          "secretsmanager:GetSecretValue"
        ],
        "Effect": "Allow",
        "Resource": [
          "${var.registry_secret_arn}"
        ]
      }
    ]
  }
  EOF
}

resource "aws_iam_role_policy_attachment" "app_role_access_registry_secret" {
  count = local.registry_secret_provided ? 1 : 0
  role       = aws_iam_role.app_role.name
  policy_arn = aws_iam_policy.access_registry_secret[0].arn
}

# -----------------------------------------------------------------------------
# Create a task definition
# -----------------------------------------------------------------------------

locals {
  repository_credentials = local.registry_secret_provided ? {
    credentialsParameter = var.registry_secret_arn
  } : null
  ecs_container_definitions = [
    {
      image = var.app_image
      repositoryCredentials = local.repository_credentials
      name        = var.app_name,
      networkMode = "awsvpc",

      portMappings = [
        {
          containerPort = var.app_port,
        }
      ]

      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = aws_cloudwatch_log_group.app.name,
          awslogs-region        = var.region,
          awslogs-stream-prefix = "ecs"
        }
      }

      environment = var.app_environment
    }
  ]
}

resource "aws_ecs_task_definition" "app" {
  family                   = "app"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.app_role.arn

  container_definitions = jsonencode(local.ecs_container_definitions)
}

# -----------------------------------------------------------------------------
# Create the ECS service
# -----------------------------------------------------------------------------

resource "aws_ecs_service" "app" {
  depends_on = [
    aws_ecs_task_definition.app,
    aws_cloudwatch_log_group.app,
    aws_alb_listener.app
  ]

  name            = var.app_name
  cluster         = aws_ecs_cluster.app.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.multi_az == true ? "2" : "1"
  launch_type     = "FARGATE"

  network_configuration {
    assign_public_ip = var.app_assign_public_ip
    security_groups  = [aws_security_group.app_ecs.id]
    subnets          = var.private_subnets
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.app.id
    container_name   = var.app_name
    container_port   = tostring(var.app_port)
  }
}

# -----------------------------------------------------------------------------
# Create the ALB
# -----------------------------------------------------------------------------

resource "aws_alb" "app" {
  name            = "${var.project_name}-${var.app_name}-${var.stage}"
  subnets         = var.public_subnets
  security_groups = [aws_security_group.app_alb.id]
}

# -----------------------------------------------------------------------------
# Create the ALB target group for ECS
# -----------------------------------------------------------------------------

resource "aws_alb_target_group" "app" {
  name        = "${var.project_name}-${var.app_name}-${var.stage}"
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path    = var.app_health_check_path
    matcher = "200-399"
  }
}

# -----------------------------------------------------------------------------
# Create the ALB listener
# -----------------------------------------------------------------------------

resource "aws_alb_listener" "app" {
  load_balancer_arn = aws_alb.app.id
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn   = aws_acm_certificate.app.arn

  default_action {
    target_group_arn = aws_alb_target_group.app.id
    type             = "forward"
  }
}

# -----------------------------------------------------------------------------
# Create the certificate
# -----------------------------------------------------------------------------

resource "aws_acm_certificate" "app" {
  domain_name       = "${var.app_subdomain}.${var.domain}"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# -----------------------------------------------------------------------------
# Validate the certificate
# -----------------------------------------------------------------------------

data "aws_route53_zone" "app" {
  name = "${var.domain}."
}

resource "aws_route53_record" "app_validation" {
  depends_on = [aws_acm_certificate.app]
  name       = element(tolist(aws_acm_certificate.app.domain_validation_options), 0)["resource_record_name"]
  type       = element(tolist(aws_acm_certificate.app.domain_validation_options), 0)["resource_record_type"]
  zone_id    = data.aws_route53_zone.app.zone_id
  records    = [element(tolist(aws_acm_certificate.app.domain_validation_options), 0)["resource_record_value"]]
  ttl        = 300
}

resource "aws_acm_certificate_validation" "app" {
  certificate_arn         = aws_acm_certificate.app.arn
  validation_record_fqdns = aws_route53_record.app_validation.*.fqdn
}

# -----------------------------------------------------------------------------
# Create Route 53 record to point to the ALB
# -----------------------------------------------------------------------------

resource "aws_route53_record" "app" {
  zone_id = data.aws_route53_zone.app.zone_id
  name    = "${var.app_subdomain}.${var.domain}"
  type    = "A"

  alias {
    name                   = aws_alb.app.dns_name
    zone_id                = aws_alb.app.zone_id
    evaluate_target_health = true
  }
}
