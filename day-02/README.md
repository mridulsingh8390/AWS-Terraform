# Day-02: EC2 with Custom `.pem` Key Pair, Custom VPC & Security Group (Public IP, Module-Based)

This guide moves beyond the **default VPC** used in Day-01. We now build a **custom VPC** (with a public subnet + internet gateway), generate a **custom key pair** (a fresh `.pem` file created by Terraform itself), attach a **Security Group**, and launch an **EC2 instance** with a **public IP address** — all as reusable Terraform modules.

> Prerequisite: Complete **Day-00** (Terraform + AWS CLI) and **Day-01** (provider/settings/state blocks, local modules).

---

## 📋 What You'll Build

```
Custom VPC (10.10.0.0/16)
  └── Internet Gateway
  └── Public Subnet (10.10.1.0/24, map_public_ip_on_launch = true)
        └── Route Table (0.0.0.0/0 → IGW)
  └── Security Group (module) — allows SSH (22) + HTTP (80)
  └── Key Pair (module) — Terraform-generated RSA key, saved locally as day02-key.pem
        └── EC2 Instance (module) — launched in the public subnet, public IP assigned
```

---

## 1. What's New vs. Day-01

| | Day-01 | Day-02 |
|---|--------|--------|
| VPC | Default VPC (read via `data`) | **Custom VPC** (created by a module) |
| Subnet | Default subnet | **Custom public subnet** + Internet Gateway + route table |
| Key pair | Existing key pair (or none) | **Terraform-generated** key pair + `.pem` saved locally |
| Public IP | Whatever the default subnet gives it | **Explicitly assigned** via `associate_public_ip_address` |

---

## 2. Project Structure

```
day-02-ec2-custom-vpc/
├── main.tf              # root module — calls child modules
├── provider.tf          # terraform + provider (+ backend) blocks
├── variables.tf         # root input variables
├── outputs.tf           # root outputs
├── terraform.tfvars     # variable values
├── .gitignore            # excludes state files & *.pem
└── modules/
    ├── vpc/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── key-pair/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── security-group/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── ec2-instance/
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

---

## 3. `provider.tf` (Root Module)

Two new providers are required this time: **`tls`** (to generate the RSA key pair) and **`local`** (to write the `.pem` file to disk).

```hcl
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }

  # Local state for this guide (default behavior — block omitted).
  # Switch to a remote S3 backend once the bucket + DynamoDB table exist:
  #
  # backend "s3" {
  #   bucket         = "day01-terraform-state-bucket"
  #   key            = "day-02/ec2-custom-vpc/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "terraform-locks"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "day-02-ec2-custom-vpc"
      Environment = "learning"
      ManagedBy   = "terraform"
    }
  }
}
```

---

## 4. `variables.tf` (Root Module)

```hcl
variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "availability_zone" {
  description = "Availability zone for the public subnet"
  type        = string
  default     = "us-east-1a"
}

variable "vpc_cidr" {
  description = "CIDR block for the custom VPC"
  type        = string
  default     = "10.10.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.10.1.0/24"
}

variable "instance_name" {
  description = "Name tag for the EC2 instance"
  type        = string
  default     = "day02-ec2-custom-vpc"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "key_name" {
  description = "Name of the AWS key pair to create (custom .pem will be generated)"
  type        = string
  default     = "day02-key"
}

variable "ssh_cidr" {
  description = "CIDR allowed to SSH into the instance (restrict this to your IP in real use)"
  type        = string
  default     = "0.0.0.0/0"
}
```

---

## 5. VPC Module (Custom VPC + Public Subnet + IGW)

### `modules/vpc/variables.tf`

```hcl
variable "name" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "public_subnet_cidr" {
  type = string
}

variable "availability_zone" {
  type = string
}
```

### `modules/vpc/main.tf`

```hcl
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.name}-vpc"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.this.id
  cidr_block               = var.public_subnet_cidr
  availability_zone        = var.availability_zone
  map_public_ip_on_launch  = true

  tags = {
    Name = "${var.name}-public-subnet"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name}-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "${var.name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}
```

### `modules/vpc/outputs.tf`

```hcl
output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnet_id" {
  value = aws_subnet.public.id
}
```

---

## 6. Key Pair Module (Generates a Custom `.pem`)

This module creates a brand-new RSA key pair **inside Terraform** (no need to pre-create one in the AWS Console), registers the public key with AWS, and writes the private key to a local `.pem` file with `0400` permissions.

### `modules/key-pair/variables.tf`

```hcl
variable "key_name" {
  description = "Name of the AWS key pair to create"
  type        = string
}

variable "save_path" {
  description = "Local directory where the generated .pem file will be saved"
  type        = string
  default     = "./"
}
```

### `modules/key-pair/main.tf`

```hcl
resource "tls_private_key" "this" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "this" {
  key_name   = var.key_name
  public_key = tls_private_key.this.public_key_openssh
}

# Saves the private key as a .pem file locally so you can SSH into the instance.
# Marked "sensitive" so the private key never appears in plan/apply console output.
resource "local_sensitive_file" "private_key_pem" {
  content         = tls_private_key.this.private_key_pem
  filename        = "${var.save_path}${var.key_name}.pem"
  file_permission = "0400"
}
```

### `modules/key-pair/outputs.tf`

```hcl
output "key_name" {
  value = aws_key_pair.this.key_name
}

output "pem_file_path" {
  value = local_sensitive_file.private_key_pem.filename
}
```

> ⚠️ The private key also lives inside `terraform.tfstate` (unencrypted, unless you use an encrypted remote backend). Treat state as sensitive — this is another reason remote state with encryption (introduced in Day-01) matters for real projects.

---

## 7. Security Group Module

### `modules/security-group/variables.tf`

```hcl
variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "ssh_cidr" {
  type = string
}
```

### `modules/security-group/main.tf`

```hcl
resource "aws_security_group" "this" {
  name        = var.name
  description = "Security group for ${var.name}"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_cidr]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = var.name
  }
}
```

### `modules/security-group/outputs.tf`

```hcl
output "security_group_id" {
  value = aws_security_group.this.id
}
```

---

## 8. EC2 Instance Module (with Public IP)

### `modules/ec2-instance/variables.tf`

```hcl
variable "name" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "security_group_ids" {
  type = list(string)
}

variable "key_pair_name" {
  type = string
}

variable "associate_public_ip" {
  description = "Whether to assign a public IP to the instance"
  type        = bool
  default     = true
}
```

### `modules/ec2-instance/main.tf`

```hcl
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
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = var.security_group_ids
  key_name                    = var.key_pair_name
  associate_public_ip_address = var.associate_public_ip

  tags = {
    Name = var.name
  }
}
```

> `associate_public_ip_address = true` is what actually assigns the **public IP** to the instance's primary network interface at launch — this only works because the subnet itself lives in a **public** route table (0.0.0.0/0 → Internet Gateway), which the VPC module sets up.

### `modules/ec2-instance/outputs.tf`

```hcl
output "instance_id" {
  value = aws_instance.this.id
}

output "public_ip" {
  value = aws_instance.this.public_ip
}

output "private_ip" {
  value = aws_instance.this.private_ip
}

output "public_dns" {
  value = aws_instance.this.public_dns
}
```

---

## 9. `main.tf` (Root Module — Wires Everything Together)

```hcl
module "vpc" {
  source = "./modules/vpc"

  name                = var.instance_name
  vpc_cidr            = var.vpc_cidr
  public_subnet_cidr  = var.public_subnet_cidr
  availability_zone   = var.availability_zone
}

module "key_pair" {
  source = "./modules/key-pair"

  key_name  = var.key_name
  save_path = "${path.module}/"
}

module "security_group" {
  source = "./modules/security-group"

  name     = "${var.instance_name}-sg"
  vpc_id   = module.vpc.vpc_id
  ssh_cidr = var.ssh_cidr
}

module "ec2_instance" {
  source = "./modules/ec2-instance"

  name                 = var.instance_name
  instance_type        = var.instance_type
  subnet_id            = module.vpc.public_subnet_id
  security_group_ids   = [module.security_group.security_group_id]
  key_pair_name        = module.key_pair.key_name
  associate_public_ip  = true
}
```

Notice the **dependency chain** flowing purely through module outputs → inputs:
`vpc.vpc_id → security_group.vpc_id`, `vpc.public_subnet_id → ec2_instance.subnet_id`, `key_pair.key_name → ec2_instance.key_pair_name`. Terraform builds the correct create-order automatically from these references — no `depends_on` needed.

---

## 10. `outputs.tf` (Root Module)

```hcl
output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet_id" {
  value = module.vpc.public_subnet_id
}

output "security_group_id" {
  value = module.security_group.security_group_id
}

output "key_name" {
  value = module.key_pair.key_name
}

output "pem_file_path" {
  value = module.key_pair.pem_file_path
}

output "instance_id" {
  value = module.ec2_instance.instance_id
}

output "instance_public_ip" {
  value = module.ec2_instance.public_ip
}

output "instance_private_ip" {
  value = module.ec2_instance.private_ip
}

output "instance_public_dns" {
  value = module.ec2_instance.public_dns
}
```

---

## 11. `terraform.tfvars`

```hcl
aws_region          = "us-east-1"
availability_zone   = "us-east-1a"
vpc_cidr            = "10.10.0.0/16"
public_subnet_cidr  = "10.10.1.0/24"
instance_name       = "day02-ec2-custom-vpc"
instance_type       = "t2.micro"
key_name            = "day02-key"
ssh_cidr            = "0.0.0.0/0"   # ⚠️ replace with YOUR_IP/32 for real use
```

---

## 12. `.gitignore`

```gitignore
# Terraform local state & working files
*.tfstate
*.tfstate.backup
.terraform/
.terraform.lock.hcl
crash.log
*.tfvars.json

# Generated private key — never commit this
*.pem
```

---

## 13. Provision the Infrastructure

```bash
terraform init
terraform plan
terraform apply -auto-approve
```

`terraform init` will download the **`tls`** and **`local`** providers in addition to `aws`, and initialize all four local modules.

⏱ Takes **~1–2 minutes** (VPC + subnet + IGW + route table + key pair + EC2 launch).

---

## 14. Verify

```bash
terraform output
```

Expected output:
```
instance_id         = "i-xxxxxxxxxxxxxxxxx"
instance_private_ip = "10.10.1.xx"
instance_public_dns = "ec2-xx-xx-xx-xx.compute-1.amazonaws.com"
instance_public_ip  = "xx.xx.xx.xx"
key_name            = "day02-key"
pem_file_path       = "./day02-key.pem"
public_subnet_id    = "subnet-xxxxxxxxxxxxxxxxx"
security_group_id   = "sg-xxxxxxxxxxxxxxxxx"
vpc_id              = "vpc-xxxxxxxxxxxxxxxxx"
```

Confirm the `.pem` file was created with the right permissions:

```bash
ls -l day02-key.pem
# -r-------- 1 you you 3243 ... day02-key.pem
```

### SSH into the Instance

```bash
ssh -i day02-key.pem ec2-user@$(terraform output -raw instance_public_ip)
```

Check it via AWS CLI too:

```bash
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=day02-ec2-custom-vpc" \
  --query "Reservations[].Instances[].[InstanceId,State.Name,PublicIpAddress,VpcId]" \
  --output table
```

---

## ✅ Summary Checklist

- [ ] Custom VPC created (10.10.0.0/16) with a public subnet, Internet Gateway, and public route table
- [ ] Key pair **generated by Terraform** (`tls_private_key` + `aws_key_pair`) and saved as `day02-key.pem` locally with `0400` permissions
- [ ] `.pem` file excluded from git via `.gitignore`
- [ ] Security Group allows SSH (22) + HTTP (80), built as a local module
- [ ] EC2 instance launched in the **custom public subnet** with `associate_public_ip_address = true`
- [ ] Public IP confirmed via `terraform output` and SSH connection succeeds
- [ ] All resources (VPC, key pair, SG, EC2) built as **separate local modules**, wired together purely through module outputs/inputs

---

## 🧹 Cleanup (avoid ongoing AWS charges)

```bash
terraform destroy -auto-approve
```

> This also deletes the AWS-side key pair (`aws_key_pair`), but your local `day02-key.pem` file will remain on disk — delete it manually if you no longer need it: `rm day02-key.pem`.

---

## Next Steps (Day-03)

- Add **private subnets** + a **NAT Gateway** so instances without public IPs can still reach the internet
- Move the EC2 instance behind an **Application Load Balancer**
- Turn on the **S3 remote backend** (introduced in Day-01) for this project's state

---

*Part of the AWS Terraform learning series — Day 02.*
