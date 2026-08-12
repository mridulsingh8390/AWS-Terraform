# Day-00: Environment Setup — Terraform & AWS CLI on Ubuntu

This guide walks through setting up a local environment on **Ubuntu** for working with **Terraform** and **AWS**.

---

## 📋 Prerequisites

- Ubuntu 20.04 / 22.04 / 24.04 (or WSL2 Ubuntu on Windows)
- A user account with `sudo` privileges
- An AWS account with an IAM user (Access Key ID + Secret Access Key)
- Internet access

---

## 1. Update System Packages

```bash
sudo apt update && sudo apt upgrade -y
```

---

## 2. Install Required Tools

Basic utilities needed for downloading and verifying packages:

```bash
sudo apt install -y gnupg software-properties-common curl wget unzip git ca-certificates lsb-release
```

| Tool | Purpose |
|------|---------|
| `curl` / `wget` | Download packages/scripts |
| `unzip` | Extract AWS CLI archive |
| `gnupg` | Verify signed repositories (HashiCorp GPG key) |
| `git` | Clone Terraform config repos |
| `lsb-release` | Detect Ubuntu codename for repo setup |

---

## 3. Install Terraform

HashiCorp provides an official APT repository — this is the recommended method (keeps Terraform updatable via `apt`).

```bash
# Add HashiCorp GPG key
wget -O- https://apt.releases.hashicorp.com/gpg | \
  gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null

# Add HashiCorp repository
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
  sudo tee /etc/apt/sources.list.d/hashicorp.list

# Update and install Terraform
sudo apt update
sudo apt install -y terraform
```

### Verify Installation

```bash
terraform -version
```

Expected output (version may differ):
```
Terraform v1.9.x
on linux_amd64
```

### Enable Tab Completion (optional)

```bash
terraform -install-autocomplete
# restart your terminal after this
```

---

## 4. Install AWS CLI (v2)

```bash
# Download the installer
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"

# Unzip it
unzip awscliv2.zip

# Run the installer
sudo ./aws/install

# Clean up
rm -rf awscliv2.zip aws/
```

### Verify Installation

```bash
aws --version
```

Expected output (version may differ):
```
aws-cli/2.x.x Python/3.x.x Linux/x.x.x
```

---

## 5. Configure AWS CLI

You'll need your IAM user's **Access Key ID** and **Secret Access Key** (create these from AWS Console → IAM → Users → Security credentials).

```bash
aws configure
```

You'll be prompted for:
```
AWS Access Key ID [None]: <your-access-key-id>
AWS Secret Access Key [None]: <your-secret-access-key>
Default region name [None]: us-east-1
Default output format [None]: json
```

This creates two files:
- `~/.aws/credentials`
- `~/.aws/config`

### Verify AWS Connectivity

```bash
aws sts get-caller-identity
```

Expected output:
```json
{
    "UserId": "AIDAXXXXXXXXXXXXX",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/your-username"
}
```

If this returns your account details, Terraform will be able to authenticate to AWS using the same credentials.

---

## 6. (Optional) Install a Code Editor

```bash
sudo snap install code --classic
```

Recommended VS Code extensions:
- **HashiCorp Terraform** (syntax highlighting, validation)
- **AWS Toolkit**

---

## 7. Terraform Architecture: Why We Use Modules

Before writing any AWS infrastructure code, it's worth understanding how Terraform projects are typically structured — because **this series is built around modules** from Day-01 onward.

### Basic Terraform Workflow

```
 write .tf files → terraform init → terraform plan → terraform apply
                         │
                         ├── downloads providers (e.g. AWS)
                         └── downloads modules
```

| Command | Purpose |
|---------|---------|
| `terraform init` | Initializes the working directory, downloads providers & modules |
| `terraform plan` | Shows what will be created/changed/destroyed |
| `terraform apply` | Applies the changes to real infrastructure |
| `terraform destroy` | Tears down everything Terraform manages |

### What Is a Module?

A **module** is just a reusable, self-contained group of `.tf` files that define a piece of infrastructure (e.g. a VPC, an EKS cluster, an S3 bucket). Every Terraform configuration technically has at least one module — the **root module** (your working directory). Modules let you call that same reusable code from other configurations, instead of duplicating it.

```
root module (your project)
   │
   ├── calls → module "vpc"    (child module)
   ├── calls → module "eks"    (child module)
   └── calls → module "iam"    (child module)
```

### Why This Series Uses Modules

- **Reusability** — write the VPC/EKS logic once, reuse it across dev/staging/prod
- **Readability** — a `main.tf` that calls `module "eks" {...}` is easier to reason about than 500 lines of raw resources
- **Community-maintained modules** — the [Terraform Registry](https://registry.terraform.io/) hosts battle-tested modules (e.g. `terraform-aws-modules/vpc/aws`, `terraform-aws-modules/eks/aws`) so we don't reinvent networking/IAM boilerplate
- **Consistency** — every day in this series follows the same folder pattern, so it's easy to follow along

### Typical Module Call Syntax

```hcl
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"   # module source (registry or local path)
  version = "~> 5.0"                          # pinned version

  name = "my-vpc"
  cidr = "10.0.0.0/16"
  # ...module-specific input variables
}
```

A module can come from:
| Source | Example |
|--------|---------|
| Terraform Registry | `terraform-aws-modules/eks/aws` |
| Local path | `./modules/vpc` |
| Git repo | `git::https://github.com/org/repo.git//modules/eks` |

### Project Structure We'll Follow

From Day-01 onward, expect a layout like this:

```
day-XX/
├── main.tf          # calls modules (vpc, eks, iam, etc.)
├── variables.tf      # input variables
├── outputs.tf        # exposed outputs
├── provider.tf        # AWS + other provider config
├── terraform.tfvars   # variable values
└── modules/            # local modules (if any are custom-built)
    └── <module-name>/
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

> 💡 Starting Day-01, resources like the EC2 instance and its Security Group will be built as **local modules** (`./modules/ec2-instance`, `./modules/security-group`) instead of raw `resource` blocks dumped in `main.tf`. Later days introduce **Terraform Registry modules** (e.g. `terraform-aws-modules/vpc/aws`) for more complex, community-maintained infrastructure like VPCs and EKS clusters.

---

## ✅ Summary Checklist

- [ ] System updated (`apt update && apt upgrade`)
- [ ] Required tools installed (`curl`, `unzip`, `gnupg`, `git`)
- [ ] Terraform installed and verified (`terraform -version`)
- [ ] AWS CLI installed and verified (`aws --version`)
- [ ] AWS CLI configured with IAM credentials (`aws configure`)
- [ ] AWS authentication verified (`aws sts get-caller-identity`)

---

## Next Steps (Day-01)

With Terraform and AWS CLI installed and authenticated, the next step is to:
1. Learn the `terraform` settings block, `provider` block, and `backend`/state block
2. Build a **Security Group** and an **EC2 instance** as local Terraform modules
3. Deploy them into your AWS account's default VPC
4. Run `terraform init`, `terraform plan`, and `terraform apply`

---

*Part of the AWS Terraform learning series — Day 00.*
