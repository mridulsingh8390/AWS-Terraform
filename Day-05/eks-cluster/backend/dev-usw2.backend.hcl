# Backend config — AWS / dev-usw2 (us-west-2 stack, SEPARATE state from dev)
# Usage (local runs only):
#   cd eks-cluster
#   terraform init -backend-config="backend/dev-usw2.backend.hcl"
bucket         = "terraform-lab-state-mridulsingh05"
key            = "eks-cluster/dev-usw2/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "terraform-state-lock"
encrypt        = true
