# Day-01: Terraform Provider, Settings, State Blocks & EC2 in Default VPC (Module-Based)

This guide covers the **core Terraform configuration blocks** (`terraform` settings block, `provider` block, and `backend`/state block), then provisions an **EC2 instance** inside your account's **default VPC**, protected by a **Security Group** — with everything built using **reusable Terraform modules**, following the module-first approach introduced in Day-00.

> Prerequisite: Complete **Day-00** (Terraform + AWS CLI installed and `aws sts get-caller-identity` working).

---

## 📋 What You'll Build

```
Default VPC (already exists in your AWS account/region)
  └── Security Group (module) — allows SSH (22) + HTTP (80)
        └── EC2 Instance (module) — launched into the default VPC/subnet
```

---

## 1. Terraform Core Blocks — Concepts

Every Terraform project starts with a few foundational blocks. It's important to understand what each one does before writing modules.

### `terraform` Block (Settings Block)

Configures Terraform itself — not your infrastructure. It pins the Terraform CLI version, declares which providers (and versions) the config depends on, and (optionally) configures the **backend** — where Terraform stores its state.

```hcl
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

| Argument | Purpose |
|----------|---------|
| `required_version` | Locks the minimum/allowed Terraform CLI version |
| `required_providers` | Declares provider name, source (registry namespace), and version constraint |
| `backend` | (Optional, nested block) Configures where the state file lives — covered below |

### `provider` Block

Configures a specific provider — here, AWS. It tells Terraform **which account/region** to talk to and how to authenticate.

```hcl
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "day-01-ec2-default-vpc"
      Environment = "learning"
      ManagedBy   = "terraform"
    }
  }
}
```

> Terraform uses credentials from `~/.aws/credentials` (set up via `aws configure` in Day-00) automatically — no keys are hardcoded in `.tf` files.

### Version Constraint Operators (quick reference)

| Operator | Meaning |
|----------|---------|
| `= 5.31.0` | Exact version only |
| `>= 5.0` | 5.0 or newer |
| `~> 5.0` | Any `5.x`, but not `6.0` (pessimistic constraint — most common) |
| `~> 5.31.0` | Any `5.31.x`, but not `5.32.0` |

---

## 2. The State Block — Understanding Terraform State

Terraform tracks every resource it manages in a **state file** (`terraform.tfstate`). This file maps your `.tf` configuration to real-world resource IDs, so Terraform knows what to create, update, or destroy on the next `plan`/`apply`.

### Local State (default — what we use in this guide)

If you don't configure a `backend`, Terraform stores state **locally**, right in your working directory:

```
day-01-ec2-default-vpc/
└── terraform.tfstate       # created automatically after the first apply
```

No block is required for this — it's the default behavior. It's fine for learning/solo work, but has real drawbacks:
- Not shared with teammates
- Not locked (two people running `apply` at once can corrupt it)
- Easy to lose (or accidentally commit secrets in it) if not gitignored

> ⚠️ Always add `terraform.tfstate`, `terraform.tfstate.backup`, and `.terraform/` to `.gitignore` — the state file can contain sensitive values in plain text.

### Remote State — `backend` Block (S3 example)

For real projects, state is stored **remotely** so it's shared, locked, and versioned. The most common AWS pattern is an **S3 bucket** (for the state file) + **DynamoDB table** (for state locking). This goes *inside* the `terraform {}` block:

```hcl
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "day01-terraform-state-bucket"   # must already exist, globally unique
    key            = "day-01/ec2-default-vpc/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"                # must already exist, for state locking
    encrypt        = true
  }
}
```

| Argument | Purpose |
|----------|---------|
| `bucket` | S3 bucket that stores the `.tfstate` file |
| `key` | Path/filename of the state file inside the bucket (unique per project) |
| `region` | Region the S3 bucket lives in |
| `dynamodb_table` | Table used to lock state during `apply` (prevents concurrent runs) |
| `encrypt` | Encrypts the state file at rest |

> 📌 **Not used in this guide (Day-01 stays on local state deliberately)** — we're introducing the concept now so the syntax is familiar. The S3 bucket + DynamoDB table themselves are chicken-and-egg (you'd normally provision them with a *separate*, simpler Terraform config or manually) — this becomes a dedicated topic in **Day-02**.

### Useful State Commands

```bash
terraform state list              # list all resources tracked in state
terraform state show <resource>   # show details of one resource in state
terraform show                    # human-readable dump of the current state
```

---

## 3. Project Structure

```
day-01-ec2-default-vpc/
├── main.tf              # root module — calls child modules
├── provider.tf          # terraform + provider (+ backend) blocks
├── variables.tf         # root input variables
├── outputs.tf           # root outputs
├── terraform.tfvars     # variable values
├── .gitignore            # excludes state files & .terraform/
└── modules/
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

## 4. `provider.tf` (Root Module)

```hcl
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Local state for this guide (default behavior — block omitted).
  # Uncomment below to switch to a remote S3 backend once the
  # bucket + DynamoDB table exist (see Day-02):
  #
  # backend "s3" {
  #   bucket         = "day01-terraform-state-bucket"
  #   key            = "day-01/ec2-default-vpc/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "terraform-locks"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "day-01-ec2-default-vpc"
      Environment = "learning"
      ManagedBy   = "terraform"
    }
  }
}
```

---

## 5. `.gitignore`

```gitignore
# Terraform local state & working files
*.tfstate
*.tfstate.backup
.terraform/
.terraform.lock.hcl
crash.log
*.tfvars.json
```

---

## 6. `variables.tf` (Root Module)

```hcl
variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "instance_name" {
  description = "Name tag for the EC2 instance"
  type        = string
  default     = "day01-ec2-default-vpc"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "ssh_cidr" {
  description = "CIDR allowed to SSH into the instance (restrict this to your IP in real use)"
  type        = string
  default     = "0.0.0.0/0"
}

variable "key_pair_name" {
  description = "Existing EC2 key pair name for SSH access"
  type        = string
  default     = null
}
```

---

## 7. Default VPC — Data Sources

We **do not create** a VPC here — every AWS account already has a **default VPC** per region. We just read it using data sources and pass it into our modules.

```hcl
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}
```

---

## 8. Security Group Module

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

## 9. EC2 Instance Module

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
  type    = string
  default = null
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
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.security_group_ids
  key_name               = var.key_pair_name

  tags = {
    Name = var.name
  }
}
```

### `modules/ec2-instance/outputs.tf`

```hcl
output "instance_id" {
  value = aws_instance.this.id
}

output "public_ip" {
  value = aws_instance.this.public_ip
}

output "public_dns" {
  value = aws_instance.this.public_dns
}
```

---

## 10. `main.tf` (Root Module — Wires Everything Together)

```hcl
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

module "security_group" {
  source = "./modules/security-group"

  name     = "${var.instance_name}-sg"
  vpc_id   = data.aws_vpc.default.id
  ssh_cidr = var.ssh_cidr
}

module "ec2_instance" {
  source = "./modules/ec2-instance"

  name                = var.instance_name
  instance_type       = var.instance_type
  subnet_id           = data.aws_subnets.default.ids[0]
  security_group_ids  = [module.security_group.security_group_id]
  key_pair_name       = var.key_pair_name
}
```

> Notice `source = "./modules/security-group"` — this is a **local module** (as opposed to the Terraform Registry modules used in earlier VPC/EKS examples). Local modules are ideal when you want full control over the resource logic yourself.

---

## 11. `outputs.tf` (Root Module)

```hcl
output "instance_id" {
  value = module.ec2_instance.instance_id
}

output "instance_public_ip" {
  value = module.ec2_instance.public_ip
}

output "instance_public_dns" {
  value = module.ec2_instance.public_dns
}

output "security_group_id" {
  value = module.security_group.security_group_id
}

output "default_vpc_id" {
  value = data.aws_vpc.default.id
}
```

---

## 12. `terraform.tfvars`

```hcl
aws_region     = "us-east-1"
instance_name  = "day01-ec2-default-vpc"
instance_type  = "t2.micro"
ssh_cidr       = "0.0.0.0/0"   # ⚠️ replace with YOUR_IP/32 for real use
key_pair_name  = null          # set to an existing key pair name if you need SSH
```

---

## 13. Provision the Infrastructure

```bash
terraform init
terraform plan
terraform apply -auto-approve
```

`terraform init` will initialize both **local modules** (`./modules/...`) — no download needed since they live in your own repo — and set up the **local state backend** by default.

---

## 14. Verify

```bash
terraform output
```

Expected output:
```
default_vpc_id      = "vpc-xxxxxxxxxxxxxxxxx"
instance_id         = "i-xxxxxxxxxxxxxxxxx"
instance_public_dns = "ec2-xx-xx-xx-xx.compute-1.amazonaws.com"
instance_public_ip  = "xx.xx.xx.xx"
security_group_id   = "sg-xxxxxxxxxxxxxxxxx"
```

Check the state file directly:

```bash
terraform state list
```

```
data.aws_subnets.default
data.aws_vpc.default
module.ec2_instance.data.aws_ami.amazon_linux
module.ec2_instance.aws_instance.this
module.security_group.aws_security_group.this
```

Check it via AWS CLI too:

```bash
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=day01-ec2-default-vpc" \
  --query "Reservations[].Instances[].[InstanceId,State.Name,PublicIpAddress]" \
  --output table
```

If you supplied a `key_pair_name`, connect via SSH:

```bash
ssh -i /path/to/key.pem ec2-user@<instance_public_ip>
```

---

## ✅ Summary Checklist

- [ ] Understand the `terraform` settings block vs. the `provider` block vs. the `backend`/state block
- [ ] Understand local state (default) vs. remote state (S3 + DynamoDB) and why teams use remote state
- [ ] `.gitignore` excludes `*.tfstate` and `.terraform/`
- [ ] Default VPC and its subnets read via `data` sources (no VPC created)
- [ ] Security Group built as a **local module** (SSH + HTTP ingress, all-outbound egress)
- [ ] EC2 instance built as a **local module**, launched into the default VPC/subnet
- [ ] Root `main.tf` wires both modules together
- [ ] `terraform apply` succeeds and outputs the instance's public IP
- [ ] Instance verified via `terraform output`, `terraform state list`, and/or AWS CLI

---

## 🧹 Cleanup (avoid ongoing AWS charges)

```bash
terraform destroy -auto-approve
```

---

## Next Steps (Day-02)

- Replace the default VPC with a **custom VPC module** (public/private subnets)
- Parameterize the EC2 module further (multiple instances, `count`/`for_each`)
- Stand up the **S3 bucket + DynamoDB table** and switch the `backend "s3"` block on for real **remote state + locking**

---

*Part of the AWS Terraform learning series — Day 01.*
