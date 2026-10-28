resource "aws_instance" "app" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.app.id]
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    dockerfile_b64 = filebase64("${path.module}/../../intern-task-app/Dockerfile")
    app_b64        = filebase64("${path.module}/../../intern-task-app/app/app.py")
  })

  user_data_replace_on_change = false

  depends_on = [aws_route_table_association.public]


  tags = {
    Name = "intern-task-app"
  }
}