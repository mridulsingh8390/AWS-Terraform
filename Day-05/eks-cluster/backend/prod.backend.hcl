# Backend config — AWS / prod
# Usage (local runs only):
#   cd eks-cluster
#   terraform init -backend-config="backend/prod.backend.hcl"
bucket         = "terraform-lab-state-mridulsingh05"
key            = "eks-cluster/prod/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "terraform-state-lock"
encrypt        = true
