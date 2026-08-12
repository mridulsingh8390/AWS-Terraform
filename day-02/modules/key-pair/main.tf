# Generates a brand-new RSA private key locally (never sent anywhere but AWS)
resource "tls_private_key" "this" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Registers the PUBLIC key with AWS so EC2 can use it for login
resource "aws_key_pair" "this" {
  key_name   = var.key_name
  public_key = tls_private_key.this.public_key_openssh
}

# Saves the PRIVATE key to disk as a .pem file with correct permissions
resource "local_file" "private_key_pem" {
  content         = tls_private_key.this.private_key_pem
  filename        = "${var.output_path}/${var.key_name}.pem"
  file_permission = "0400"
}
