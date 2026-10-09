# Backend config — AWS / qa
# Usage (local runs only):
#   cd eks-cluster
#   terraform init -backend-config="backend/qa.backend.hcl"
bucket         = "terraform-lab-state-mridulsingh05"
key            = "eks-cluster/qa/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "terraform-state-lock"
encrypt        = true
