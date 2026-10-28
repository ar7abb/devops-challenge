resource "aws_security_group" "app" {
  name        = "intern-task-app"
  description = "Allow app traffic and restricted SSH"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from the specified network"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_cidr]
  }

  ingress {
    description = "Public access to the app"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Outbound access for installation and downloads"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}