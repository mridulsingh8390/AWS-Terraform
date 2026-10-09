# Backend config — AWS / dev
# Usage (local runs only):
#   cd eks-cluster
#   terraform init -backend-config="backend/dev.backend.hcl"
bucket         = "terraform-lab-state-mridulsingh05"
key            = "eks-cluster/dev/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "terraform-state-lock"
encrypt        = true
