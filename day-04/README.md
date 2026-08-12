# Day-04: Amazon EKS with 1 Node Group + OIDC (Module-Based) + Separate Deployment Folder

This guide moves from EC2-based compute (Day-02/Day-03) to **Amazon EKS**. It provisions a **custom VPC**, an **EKS cluster** with **one managed node group**, and enables the **IAM OIDC provider** (required for IRSA) — all built as **local Terraform modules**. Kubernetes manifests (Deployment + Service) live in a **separate `deployment/` folder**, kept independent from the Terraform infrastructure code.

> Prerequisite: Complete **Day-00** through **Day-03**.

---

## 📋 What You'll Build

```
day-04-eks-oidc/                       ← Terraform infrastructure
Custom VPC (10.30.0.0/16)
  └── Internet Gateway
  └── Public Subnet A (10.30.1.0/24, AZ-a)
  └── Public Subnet B (10.30.2.0/24, AZ-b)
        └── EKS Cluster (control plane)
              └── OIDC Provider (IAM) — enables IRSA
              └── Managed Node Group (1 group, 2 desired nodes)
              └── IRSA Role — for the AWS Load Balancer Controller

deployment/                            ← Kubernetes manifests (separate, applied via kubectl)
  ├── deployment.yaml                    (nginx, 2 replicas)
  ├── service.yaml                       (ClusterIP — internal only)
  ├── alb-controller-serviceaccount.yaml (annotated with the IRSA role ARN)
  └── ingress.yaml                       (ALB annotations — THIS creates the ALB)
```

> ⚠️ **Not using `Service: type: LoadBalancer` here.** That would spin up a brand-new Classic/Network Load Balancer completely separate from the ALB pattern built in Day-03. Instead we install the **AWS Load Balancer Controller** and expose the app through an **Ingress** — the controller watches Ingress resources and provisions/manages an **actual ALB** for you. This is also the whole reason the **OIDC provider** exists in this module: the controller needs an IRSA role to call the AWS API and create/manage that ALB.

---

## 1. Why a Separate `deployment/` Folder?

Terraform manages **infrastructure** (the cluster, node group, IAM, networking). It's deliberately **not** used here to manage Kubernetes workloads — that's `kubectl`'s job. Keeping `deployment/` separate from the `.tf` files means:

- Infra changes (`terraform apply`) and app changes (`kubectl apply`) have independent lifecycles
- Anyone with `kubectl` access can update the app without needing Terraform state access
- It mirrors how most real teams split **platform** (Terraform) from **workloads** (GitOps/kubectl/Helm)

---

## 2. Project Structure

```
day-04-eks-oidc/
├── main.tf                    # root module — calls vpc + eks-cluster + irsa-role modules
├── provider.tf
├── variables.tf
├── outputs.tf
├── terraform.tfvars
├── .gitignore
├── modules/
│   ├── vpc/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── eks-cluster/            # cluster + node group + OIDC, all in one module
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── irsa-role/               # generic IRSA role, used by the ALB Controller
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
└── deployment/                  # SEPARATE from Terraform — plain Kubernetes manifests
    ├── deployment.yaml
    ├── service.yaml                       (ClusterIP)
    ├── alb-controller-serviceaccount.yaml  (annotated with the IRSA role ARN)
    └── ingress.yaml                        (creates the ALB via the controller)
```

---

## 3. VPC Module — Tagged for EKS

Same 2-public-subnet pattern as Day-03, plus the special tags EKS and the AWS Load Balancer Controller look for:

```hcl
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.name}-vpc"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.this.id
  cidr_block               = var.public_subnet_cidrs[count.index]
  availability_zone         = var.availability_zones[count.index]
  map_public_ip_on_launch  = true

  tags = {
    Name = "${var.name}-public-subnet-${count.index + 1}"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                     = "1"
  }
}
```

| Tag | Purpose |
|-----|---------|
| `kubernetes.io/cluster/<name> = shared` | Tells EKS this VPC/subnet belongs to the cluster |
| `kubernetes.io/role/elb = 1` | Tells the AWS Load Balancer Controller these subnets can host public ELBs/ALBs |

---

## 4. EKS Cluster Module — Cluster + OIDC + Node Group

This module builds everything hands-on (no Registry module), so each piece is visible.

### 4a. IAM Role for the Control Plane

```hcl
data "aws_iam_policy_document" "cluster_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster" {
  name               = "${var.cluster_name}-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.cluster_assume_role.json
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}
```

### 4b. The EKS Cluster Itself

```hcl
resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  version  = var.cluster_version
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_public_access  = true
    endpoint_private_access = false
  }

  depends_on = [aws_iam_role_policy_attachment.cluster_policy]
}
```

### 4c. OIDC Provider — Enables IRSA

Every EKS cluster exposes an OIDC issuer URL. Registering it as an **IAM OIDC Identity Provider** lets you attach IAM roles directly to Kubernetes ServiceAccounts (IRSA) instead of giving nodes broad permissions.

```hcl
data "tls_certificate" "eks_oidc" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_oidc.certificates[0].sha1_fingerprint]
}
```

`tls_certificate` fetches the cluster's TLS cert so Terraform can compute the SHA1 thumbprint AWS requires to trust the issuer.

### 4d. IAM Role for the Node Group

```hcl
data "aws_iam_policy_document" "node_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "node" {
  name               = "${var.cluster_name}-node-role"
  assume_role_policy = data.aws_iam_policy_document.node_assume_role.json
}

resource "aws_iam_role_policy_attachment" "node_worker_policy" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_cni_policy" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "node_ecr_readonly" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}
```

### 4e. The Managed Node Group (1 group)

```hcl
resource "aws_eks_node_group" "default" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-ng-default"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.subnet_ids
  instance_types  = [var.node_instance_type]

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_worker_policy,
    aws_iam_role_policy_attachment.node_cni_policy,
    aws_iam_role_policy_attachment.node_ecr_readonly,
  ]
}
```

---

## 5. IRSA Role Module — For the AWS Load Balancer Controller

The whole reason Day-04 sets up the OIDC provider is **this module**. It creates an IAM role that a Kubernetes ServiceAccount can assume directly — no static AWS credentials stored in the cluster.

```hcl
locals {
  oidc_provider_host = replace(var.oidc_provider_url, "https://", "")
}

data "aws_iam_policy_document" "irsa_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_host}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${var.service_account_name}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_host}:aud"
      values   = ["sts.amazonaws.com"]
    }

    principals {
      identifiers = [var.oidc_provider_arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "this" {
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.irsa_trust.json
}

resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.this.name
  policy_arn = var.policy_arn
}
```

The `sub` condition pins this role to **one specific ServiceAccount** (`kube-system/aws-load-balancer-controller`) — no other pod in the cluster can assume it. This module is generic enough to reuse for any future workload that needs AWS API access via IRSA, not just the ALB Controller.

It's wired into the root module like this:

```hcl
module "alb_controller_irsa" {
  source = "./modules/irsa-role"

  role_name             = "${var.cluster_name}-alb-controller-role"
  oidc_provider_arn     = module.eks.oidc_provider_arn
  oidc_provider_url     = module.eks.oidc_provider_url
  namespace             = "kube-system"
  service_account_name  = "aws-load-balancer-controller"
  policy_arn            = var.alb_controller_policy_arn
}
```

`var.alb_controller_policy_arn` is deliberately **not defaulted** — you supply it after creating the AWS Load Balancer Controller's IAM policy (step below).

---

## 6. `main.tf` (Root Module)

```hcl
module "vpc" {
  source = "./modules/vpc"

  name                  = var.project_name
  vpc_cidr               = var.vpc_cidr
  public_subnet_cidrs   = var.public_subnet_cidrs
  availability_zones     = var.availability_zones
  cluster_name           = var.cluster_name
}

module "eks" {
  source = "./modules/eks-cluster"

  cluster_name          = var.cluster_name
  cluster_version       = var.cluster_version
  vpc_id                = module.vpc.vpc_id
  subnet_ids            = module.vpc.public_subnet_ids
  node_instance_type    = var.node_instance_type
  node_desired_size     = var.node_desired_size
  node_min_size         = var.node_min_size
  node_max_size         = var.node_max_size
}
```

---

## 7. `variables.tf`

```hcl
variable "aws_region"          { type = string; default = "us-east-1" }
variable "project_name"        { type = string; default = "day04-eks" }
variable "cluster_name"        { type = string; default = "day04-eks-cluster" }
variable "cluster_version"     { type = string; default = "1.30" }
variable "vpc_cidr"            { type = string; default = "10.30.0.0/16" }
variable "public_subnet_cidrs" { type = list(string); default = ["10.30.1.0/24", "10.30.2.0/24"] }
variable "availability_zones"  { type = list(string); default = ["us-east-1a", "us-east-1b"] }
variable "node_instance_type"  { type = string; default = "t3.medium" }
variable "node_desired_size"   { type = number; default = 2 }
variable "node_min_size"       { type = number; default = 1 }
variable "node_max_size"       { type = number; default = 3 }

# No default — supplied after creating the ALB Controller IAM policy (see step 12)
variable "alb_controller_policy_arn" {
  type = string
}
```

---

## 8. `outputs.tf`

```hcl
output "vpc_id"                  { value = module.vpc.vpc_id }
output "public_subnet_ids"       { value = module.vpc.public_subnet_ids }
output "cluster_name"            { value = module.eks.cluster_name }
output "cluster_endpoint"        { value = module.eks.cluster_endpoint }
output "oidc_provider_arn"       { value = module.eks.oidc_provider_arn }
output "oidc_provider_url"       { value = module.eks.oidc_provider_url }
output "node_group_name"         { value = module.eks.node_group_name }
output "alb_controller_role_arn" { value = module.alb_controller_irsa.role_arn }
```

---

## 9. `terraform.tfvars`

```hcl
aws_region            = "us-east-1"
project_name          = "day04-eks"
cluster_name          = "day04-eks-cluster"
cluster_version       = "1.30"
vpc_cidr              = "10.30.0.0/16"
public_subnet_cidrs   = ["10.30.1.0/24", "10.30.2.0/24"]
availability_zones     = ["us-east-1a", "us-east-1b"]
node_instance_type    = "t3.medium"
node_desired_size     = 2
node_min_size         = 1
node_max_size         = 3

# alb_controller_policy_arn is intentionally left out here —
# pass it with -var after step 12, e.g.:
# terraform apply -var="alb_controller_policy_arn=arn:aws:iam::123456789012:policy/AWSLoadBalancerControllerIAMPolicy"
```

---

## 10. Create the ALB Controller IAM Policy (one-time, before `apply`)

The AWS Load Balancer Controller needs a fairly broad IAM policy (create/manage ALBs, target groups, security groups, etc.) — this is the official policy published by AWS, so it's created once via the AWS CLI rather than hand-typed into Terraform:

```bash
curl -o alb-controller-iam-policy.json \
  https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json

aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://alb-controller-iam-policy.json
```

Note the `Arn` from the output (or fetch it again anytime with):

```bash
aws iam list-policies --query "Policies[?PolicyName=='AWSLoadBalancerControllerIAMPolicy'].Arn" --output text
```

---

## 11. Provision the Cluster

```bash
terraform init
terraform plan -var="alb_controller_policy_arn=<POLICY_ARN_FROM_STEP_10>"
terraform apply -auto-approve -var="alb_controller_policy_arn=<POLICY_ARN_FROM_STEP_10>"
```

Or add it permanently to `terraform.tfvars` instead of passing `-var` every time.

⏱ Takes **~12–15 minutes** — EKS control plane + node group provisioning is slow.

---

## 12. Connect `kubectl`

```bash
aws eks update-kubeconfig \
  --region us-east-1 \
  --name day04-eks-cluster
```

```bash
kubectl get nodes
```

Expected:
```
NAME                          STATUS   ROLES    AGE   VERSION
ip-10-30-1-xx.ec2.internal    Ready    <none>   2m    v1.30.x
ip-10-30-2-xx.ec2.internal    Ready    <none>   2m    v1.30.x
```

### Verify the OIDC Provider

```bash
terraform output oidc_provider_url
aws iam list-open-id-connect-providers
```

The ARN in the CLI output should match `oidc_provider_arn` from `terraform output`.

---

## 13. Install the AWS Load Balancer Controller (Helm)

```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  --namespace kube-system \
  --set clusterName=day04-eks-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller
```

`serviceAccount.create=false` because we create it ourselves in `deployment/alb-controller-serviceaccount.yaml`, annotated with the IRSA role Terraform just created — apply that first:

```bash
# Fill in the role ARN from Terraform, then apply
export ROLE_ARN=$(terraform output -raw alb_controller_role_arn)
sed "s|<ALB_CONTROLLER_ROLE_ARN>|$ROLE_ARN|" deployment/alb-controller-serviceaccount.yaml | kubectl apply -f -
```

> Apply the ServiceAccount **before** the `helm install` step above, so the controller's pod picks up the IRSA-annotated identity on first start.

Verify the controller pod is running:

```bash
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
```

---

## 14. Deploy the Sample App (from the separate `deployment/` folder)

```bash
cd deployment
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f ingress.yaml
```

(`alb-controller-serviceaccount.yaml` was already applied in step 13.)

### `deployment/deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sample-nginx
  labels:
    app: sample-nginx
spec:
  replicas: 2
  selector:
    matchLabels:
      app: sample-nginx
  template:
    metadata:
      labels:
        app: sample-nginx
    spec:
      containers:
        - name: nginx
          image: nginx:1.27-alpine
          ports:
            - containerPort: 80
          resources:
            requests:
              cpu: "100m"
              memory: "128Mi"
            limits:
              cpu: "250m"
              memory: "256Mi"
```

### `deployment/service.yaml` — `ClusterIP`, not `LoadBalancer`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: sample-nginx-svc
spec:
  type: ClusterIP
  selector:
    app: sample-nginx
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
```

The Service is only reachable **inside** the cluster now. External traffic comes in through the ALB → Ingress → Service chain instead.

### `deployment/ingress.yaml` — This Is What Creates the ALB

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: sample-nginx-ingress
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}]'
spec:
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: sample-nginx-svc
                port:
                  number: 80
```

The `kubernetes.io/ingress.class: alb` annotation tells the AWS Load Balancer Controller (installed in step 13) to watch this resource and provision a real **Application Load Balancer** for it — the same kind of resource built manually in Day-03, just now managed declaratively through Kubernetes.

### Verify

```bash
kubectl get pods -l app=sample-nginx
kubectl get ingress sample-nginx-ingress -w
```

Once the `ADDRESS` column populates (~2–3 min while the controller provisions the ALB):

```bash
INGRESS_HOST=$(kubectl get ingress sample-nginx-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl http://$INGRESS_HOST
```

Confirm it in the AWS Console/CLI too — this ALB is tagged and managed by the controller, not by Terraform:

```bash
aws elbv2 describe-load-balancers --query "LoadBalancers[?contains(LoadBalancerName, 'k8s-default-samplengi')]"
```

---

## ✅ Summary Checklist

- [ ] Custom VPC with 2 public subnets, tagged for EKS/ELB discovery
- [ ] EKS cluster provisioned with a dedicated cluster IAM role
- [ ] **OIDC provider** registered (`aws iam list-open-id-connect-providers` confirms it)
- [ ] **1 managed node group** with its own IAM role (worker + CNI + ECR-readonly policies)
- [ ] `kubeconfig` updated and `kubectl get nodes` returns Ready nodes
- [ ] AWS Load Balancer Controller IAM policy created via AWS CLI
- [ ] **IRSA role** created via Terraform (`irsa-role` module), scoped to `kube-system/aws-load-balancer-controller`
- [ ] ALB Controller installed via Helm and its pod is `Running`
- [ ] Kubernetes manifests kept in a **separate `deployment/` folder**, applied via `kubectl` (not Terraform)
- [ ] Service is `ClusterIP` — **not** `LoadBalancer` — traffic flows through the Ingress instead
- [ ] Ingress reachable, and its `ADDRESS` points to a real ALB (confirmed via AWS CLI/Console)

---

## 🧹 Cleanup

```bash
kubectl delete -f deployment/ingress.yaml       # deletes the ALB first
kubectl delete -f deployment/service.yaml
kubectl delete -f deployment/deployment.yaml
helm uninstall aws-load-balancer-controller -n kube-system
kubectl delete -f deployment/alb-controller-serviceaccount.yaml
terraform destroy -auto-approve
```

> Delete the **Ingress** (and thus its ALB) **before** `terraform destroy` — the ALB was created by the controller, not by Terraform, so Terraform doesn't know to clean it up and it can be left orphaned (and billing) otherwise.

---

## Next Steps (Day-05)

- Add host- and path-based routing rules to the Ingress for multiple services
- Enable HTTPS on the ALB via `alb.ingress.kubernetes.io/certificate-arn` (ACM)
- Move Terraform state to a **remote S3 backend** (introduced conceptually in Day-01)

---

*Part of the AWS Terraform learning series — Day 04.*
