data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "this" {
  count = var.instance_count

  ami                         = data.aws_ami.amazon_linux.id
  instance_type                = var.instance_type
  subnet_id                     = element(var.subnet_ids, count.index)
  vpc_security_group_ids        = var.security_group_ids
  key_name                      = var.key_name
  associate_public_ip_address   = true

  # Simple demo web server so the ALB has something to health-check / serve
  user_data = <<-EOT
    #!/bin/bash
    dnf install -y httpd
    systemctl enable httpd
    systemctl start httpd
    echo "<h1>Hello from $(hostname -f) - instance ${count.index + 1}</h1>" > /var/www/html/index.html
  EOT

  tags = {
    Name = "${var.name}-${count.index + 1}"
  }
}
