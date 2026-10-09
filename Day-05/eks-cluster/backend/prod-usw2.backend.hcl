# Backend config — AWS / prod-usw2 (us-west-2 stack, SEPARATE state from prod)
# Usage (local runs only):
#   cd eks-cluster
#   terraform init -backend-config="backend/prod-usw2.backend.hcl"
bucket         = "terraform-lab-state-mridulsingh05"
key            = "eks-cluster/prod-usw2/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "terraform-state-lock"
encrypt        = true
