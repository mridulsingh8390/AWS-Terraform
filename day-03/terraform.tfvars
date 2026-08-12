aws_region           = "us-east-1"
project_name         = "day03-alb"
vpc_cidr             = "10.20.0.0/16"
public_subnet_cidrs  = ["10.20.1.0/24", "10.20.2.0/24"]
availability_zones   = ["us-east-1a", "us-east-1b"]
instance_type        = "t2.micro"
instance_count       = 2
ssh_cidr             = "0.0.0.0/0"
