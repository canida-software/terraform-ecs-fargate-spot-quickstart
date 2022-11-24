output "app_image" {
  description = "App Image"
  value       = var.app_image
}

output "domain" {
  description = "Domain"
  value       = aws_route53_record.app.name
}
