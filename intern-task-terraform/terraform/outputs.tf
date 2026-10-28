output "public_ip" {
  description = "Public IPv4 address of the app instance"
  value       = aws_instance.app.public_ip
}

output "app_port" {
  description = "Port the app listens on"
  value       = 5000
}