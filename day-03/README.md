# Day-03: 2 EC2 Instances + Target Group + ALB (Custom VPC, SG & PEM, Module-Based)

This guide builds on Day-02's custom VPC/SG/PEM pattern and adds **two EC2 instances** behind an **Application Load Balancer (ALB)**, registered in a **Target Group** — all via reusable Terraform modules.

> Prerequisite: Complete **Day-00**, **Day-01**, and **Day-02**.

---

## 📋 What You'll Build

```
Custom VPC (10.20.0.0/16)
  └── Internet Gateway
  └── Public Subnet A (10.20.1.0/24, AZ-a)   ─┐
  └── Public Subnet B (10.20.2.0/24, AZ-b)   ─┴─ required: ALB needs 2+ AZs
        │
        ├── ALB Security Group — HTTP (80) open to internet
        ├── EC2 Security Group — SSH (22) from you, HTTP (80) ONLY from ALB SG
        ├── Custom Key Pair — Terraform-generated day03-alb-key.pem
        │
        ├── EC2 Instance 1 (Apache, "Hello from instance 1")
        ├── EC2 Instance 2 (Apache, "Hello from instance 2")
        │
        └── Application Load Balancer
              └── Listener (HTTP:80)
                    └── Target Group → [instance 1, instance 2]
```

---

## 1. What's New vs. Day-02

| | Day-02 | Day-03 |
|---|--------|--------|
| Subnets | 1 public subnet | **2 public subnets** (2 AZs — ALB requirement) |
| Security Groups | 1 SG | **2 SGs** — ALB SG (internet-facing) + EC2 SG (ALB-only) |
| EC2 instances | 1 | **2**, via `count`, spread across subnets |
| New module | — | **`alb`** module (ALB + Target Group + Listener + Attachments) |
| Traffic path | Direct to instance | **Internet → ALB → Target Group → Instances** |

---

## 2. Project Structure

```
day-03-alb-ec2/
├── main.tf
├── provider.tf
├── variables.tf
├── outputs.tf
├── terraform.tfvars
├── .gitignore
└── modules/
    ├── vpc/                  # 2 public subnets across 2 AZs
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── security-group/       # separate ALB SG + EC2 SG
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── key-pair/              # generates a fresh .pem, same as Day-02
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── ec2-instance/          # count-based, multiple instances
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── alb/                    # NEW: ALB + Target Group + Listener
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

---

## 3. VPC Module — Now With 2 Public Subnets

An ALB requires subnets in **at least two Availability Zones**, so the VPC module now takes lists and uses `count`:

```hcl
resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.this.id
  cidr_block               = var.public_subnet_cidrs[count.index]
  availability_zone         = var.availability_zones[count.index]
  map_public_ip_on_launch  = true

  tags = {
    Name = "${var.name}-public-subnet-${count.index + 1}"
  }
}
```

Both subnets share a single route table pointing at the Internet Gateway (same pattern as Day-02, just looped with `count`).

---

## 4. Security Group Module — Split Into Two

This is the key security pattern for load-balanced architectures: **the EC2 instances should never be reachable directly from the internet — only through the ALB.**

```hcl
# ALB SG — open to the internet on port 80
resource "aws_security_group" "alb" {
  name   = "${var.name}-alb-sg"
  vpc_id = var.vpc_id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2 SG — HTTP allowed ONLY from the ALB's security group
resource "aws_security_group" "ec2" {
  name   = "${var.name}-ec2-sg"
  vpc_id = var.vpc_id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_cidr]
  }

  ingress {
    description     = "HTTP from ALB only"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

Notice `security_groups = [aws_security_group.alb.id]` instead of a CIDR block — this is a **security-group-to-security-group** reference, the standard AWS pattern for "only allow traffic that came from this other SG."

---

## 5. Key Pair Module — Same as Day-02

```hcl
resource "tls_private_key" "this" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "this" {
  key_name   = var.key_name
  public_key = tls_private_key.this.public_key_openssh
}

resource "local_file" "private_key_pem" {
  content         = tls_private_key.this.private_key_pem
  filename        = "${var.output_path}/${var.key_name}.pem"
  file_permission = "0400"
}
```

---

## 6. EC2 Instance Module — Now Multiple Instances via `count`

```hcl
resource "aws_instance" "this" {
  count = var.instance_count

  ami                         = data.aws_ami.amazon_linux.id
  instance_type                = var.instance_type
  subnet_id                     = element(var.subnet_ids, count.index)
  vpc_security_group_ids        = var.security_group_ids
  key_name                      = var.key_name
  associate_public_ip_address   = true

  # Simple demo web server so the ALB has something to serve/health-check
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
```

`element(var.subnet_ids, count.index)` round-robins instances across the two public subnets. `user_data` installs Apache on boot so each instance actually serves something the ALB can health-check and route to.

---

## 7. ALB Module — Target Group, Listener, Attachments

```hcl
resource "aws_lb" "this" {
  name               = "${var.name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = var.security_group_ids
  subnets            = var.subnet_ids
}

resource "aws_lb_target_group" "this" {
  name     = "${var.name}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 15
  }
}

resource "aws_lb_target_group_attachment" "this" {
  count = length(var.target_instance_ids)

  target_group_arn = aws_lb_target_group.this.arn
  target_id        = var.target_instance_ids[count.index]
  port             = 80
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port               = 80
  protocol           = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}
```

| Resource | Purpose |
|----------|---------|
| `aws_lb` | The ALB itself — spans both public subnets |
| `aws_lb_target_group` | Defines health check + where traffic gets forwarded |
| `aws_lb_target_group_attachment` | Registers each EC2 instance ID into the target group |
| `aws_lb_listener` | Listens on port 80, forwards to the target group |

---

## 8. `main.tf` (Root Module — Wires Everything Together)

```hcl
module "vpc" {
  source = "./modules/vpc"

  name                  = var.project_name
  vpc_cidr               = var.vpc_cidr
  public_subnet_cidrs   = var.public_subnet_cidrs
  availability_zones     = var.availability_zones
}

module "security_group" {
  source = "./modules/security-group"

  name     = var.project_name
  vpc_id   = module.vpc.vpc_id
  ssh_cidr = var.ssh_cidr
}

module "key_pair" {
  source = "./modules/key-pair"

  key_name    = "${var.project_name}-key"
  output_path = "${path.module}"
}

module "ec2_instances" {
  source = "./modules/ec2-instance"

  name                = var.project_name
  instance_count      = var.instance_count
  instance_type       = var.instance_type
  subnet_ids          = module.vpc.public_subnet_ids
  security_group_ids  = [module.security_group.ec2_security_group_id]
  key_name            = module.key_pair.key_name
}

module "alb" {
  source = "./modules/alb"

  name                  = var.project_name
  vpc_id                 = module.vpc.vpc_id
  subnet_ids            = module.vpc.public_subnet_ids
  security_group_ids    = [module.security_group.alb_security_group_id]
  target_instance_ids   = module.ec2_instances.instance_ids
}
```

---

## 9. `variables.tf`

```hcl
variable "aws_region"          { type = string; default = "us-east-1" }
variable "project_name"        { type = string; default = "day03-alb" }
variable "vpc_cidr"            { type = string; default = "10.20.0.0/16" }
variable "public_subnet_cidrs" { type = list(string); default = ["10.20.1.0/24", "10.20.2.0/24"] }
variable "availability_zones"  { type = list(string); default = ["us-east-1a", "us-east-1b"] }
variable "instance_type"       { type = string; default = "t2.micro" }
variable "instance_count"      { type = number; default = 2 }
variable "ssh_cidr"            { type = string; default = "0.0.0.0/0" }
```

---

## 10. `outputs.tf`

```hcl
output "vpc_id"                { value = module.vpc.vpc_id }
output "public_subnet_ids"     { value = module.vpc.public_subnet_ids }
output "alb_security_group_id" { value = module.security_group.alb_security_group_id }
output "ec2_security_group_id" { value = module.security_group.ec2_security_group_id }
output "key_name"              { value = module.key_pair.key_name }
output "pem_file_path"         { value = module.key_pair.private_key_pem_path }
output "instance_ids"          { value = module.ec2_instances.instance_ids }
output "instance_public_ips"   { value = module.ec2_instances.public_ips }
output "alb_dns_name"          { value = module.alb.alb_dns_name }
output "target_group_arn"      { value = module.alb.target_group_arn }
```

---

## 11. `terraform.tfvars`

```hcl
aws_region           = "us-east-1"
project_name         = "day03-alb"
vpc_cidr             = "10.20.0.0/16"
public_subnet_cidrs  = ["10.20.1.0/24", "10.20.2.0/24"]
availability_zones   = ["us-east-1a", "us-east-1b"]
instance_type        = "t2.micro"
instance_count       = 2
ssh_cidr             = "0.0.0.0/0"   # ⚠️ replace with YOUR_IP/32 for real use
```

---

## 12. Provision

```bash
terraform init
terraform plan
terraform apply -auto-approve
```

⏱ ALB provisioning + target health checks typically take **2–4 minutes** after `apply` completes before targets show `healthy`.

---

## 13. Verify

```bash
terraform output
```

```
alb_dns_name          = "day03-alb-alb-123456789.us-east-1.elb.amazonaws.com"
ec2_security_group_id = "sg-xxxxxxxxxxxxxxxxx"
alb_security_group_id = "sg-yyyyyyyyyyyyyyyyy"
instance_ids           = ["i-xxxx...", "i-yyyy..."]
instance_public_ips    = ["x.x.x.x", "y.y.y.y"]
key_name               = "day03-alb-key"
pem_file_path          = "./day03-alb-key.pem"
```

Check target health:

```bash
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw target_group_arn)
```

Hit the load balancer (refresh a few times — you should see traffic alternate between instance 1 and instance 2):

```bash
curl http://$(terraform output -raw alb_dns_name)
```

SSH directly into an instance if needed (SSH still bypasses the ALB, per the SG rules):

```bash
ssh -i day03-alb-key.pem ec2-user@$(terraform output -json instance_public_ips | jq -r '.[0]')
```

---

## ✅ Summary Checklist

- [ ] VPC with **2 public subnets across 2 AZs**
- [ ] Two distinct Security Groups: ALB SG (internet-facing) + EC2 SG (ALB-only access)
- [ ] Custom `.pem` key generated via the `key-pair` module
- [ ] **2 EC2 instances** created via `count`, each running Apache via `user_data`
- [ ] ALB + Target Group + Listener created via the `alb` module
- [ ] Both instances registered in the target group and reporting `healthy`
- [ ] `curl`-ing the ALB DNS name returns responses from both instances

---

## 🧹 Cleanup

```bash
terraform destroy -auto-approve
rm -f day03-alb-key.pem
```

---

## Next Steps (Day-04)

- Move from EC2-based compute to **Amazon EKS** with a **managed node group**
- Enable the **OIDC provider** for IRSA
- Deploy a sample app to the cluster from a **separate `deployment/` folder** (Deployment + Service manifests)

---

*Part of the AWS Terraform learning series — Day 03.*
