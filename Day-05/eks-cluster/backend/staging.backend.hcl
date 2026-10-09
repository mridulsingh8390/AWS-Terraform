# Backend config — AWS / staging
# Usage (local runs only):
#   cd eks-cluster
#   terraform init -backend-config="backend/staging.backend.hcl"
bucket         = "terraform-lab-state-mridulsingh05"
key            = "eks-cluster/staging/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "terraform-state-lock"
encrypt        = true
