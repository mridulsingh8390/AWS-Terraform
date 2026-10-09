# Project Dragonfly Terraform Update

This package extends the original EKS lab foundation toward the Project Dragonfly / Unity Communication Platform requirements described in the supplied SOW and Change Request.

## Included Dragonfly foundation changes

- EKS managed node groups default to **Bottlerocket FIPS** (`BOTTLEROCKET_x86_64_FIPS`).
- EKS API endpoint defaults to **private-only** in the supplied environment tfvars.
- CMK encryption remains enabled for EKS secrets and node EBS volumes.
- Private AWS service endpoints for ECR API/Docker, KMS FIPS, STS, CloudWatch Logs, CloudWatch Monitoring, Secrets Manager, ELB, and S3 gateway.
- LiveKit recording S3 bucket with KMS encryption, versioning, public-access blocking, Object Lock, and Glacier lifecycle transition.
- WebRTC/STUN UDP and configurable SIP TCP/UDP rules; facility CIDRs are intentionally empty until Securus approves them.
- Reusable Route 53 geolocation/health-check module for active-active regional routing.
- Reusable inter-region Transit Gateway module.
- Environment tags aligned to `rtc-platform-dev`, `rtc-platform-qa`, and `rtc-platform-prod`.
- Existing ALB controller, EFS, IAM, and KMS capabilities are retained.

## Important deployment notes

1. **This is infrastructure foundation code, not the complete application platform.** LiveKit, LiveKit SIP, LiveKit Egress, STUNner, RabbitMQ, Chainguard images, PKI/mTLS, Splunk integration, and application Helm/ArgoCD releases still require their approved implementation/configuration.
2. The SOW/CR call for Securus-specific inputs such as CIDRs, PKI, RTO/RPO, SLOs, security controls, and acceptance criteria. These are not invented in this package.
3. The recording bucket uses **GOVERNANCE Object Lock** by default (`recording_object_lock_mode`). Switch prod to `COMPLIANCE` only after Securus confirms the retention period, because COMPLIANCE retention cannot be shortened or removed by anyone, including root. Dev/qa/staging use a 7-day placeholder retention so lab buckets can be cleaned up.
4. `enable_nat_gateway = true` remains the default so the lab can bootstrap external dependencies. A true no-internet-egress production design requires approved private/mirrored registries and a validated endpoint strategy before NAT is removed.
5. Each region has its own Terraform state. `values/<env>-usw2.tfvars` + `backend/<env>-usw2.backend.hcl` deploy the **us-west-2** stack (state key `eks-cluster/<env>-usw2/terraform.tfstate`); `dev`/`qa`/`prod` remain the us-east-1 stacks. All VPC CIDRs are unique **placeholders** (see fix 12); replace them with the Securus IPAM allocation. The Transit Gateway module is wired in behind `enable_transit_gateway` (off by default); the Route 53 module is not wired in. See "Known gaps" below.
6. The supplied Kubernetes version remains environment-specific. Validate the selected EKS version against the Securus-approved platform baseline before production rollout.
7. `terraform init/validate/plan` could not be run against AWS in the review environment (no provider registry access). The code was checked with `tofu fmt` (syntax), plus a static check that every module argument, variable reference and tfvars key is declared. Run the following locally/CI before apply:

```bash
cd eks-cluster
terraform init
terraform fmt -recursive
terraform validate
terraform plan -var-file=values/dev.tfvars
```

## Validation pass (what was fixed)

| # | Severity | Fix |
|---|---|---|
| 1 | Blocker | `variables.tf` in `route53-geolocation`, `transit-gateway`, `s3-recording`, `vpc-endpoints` used invalid single-line blocks with two arguments; `terraform validate` failed. Rewritten. |
| 2 | Blocker | `modules/eks/main.tf`: Helm annotation key `eks\.amazonaws\.com/role-arn` needs `\\.` inside an HCL string (invalid escape). Fixed. |
| 3 | High | us-west-2 stacks had tfvars but no backend file and were not selectable in CI, so a run would reuse the us-east-1 state key. Added `*-usw2.backend.hcl` (separate state keys) and the three `*-usw2` options in `.gitlab-ci.yml`. |
| 4 | High | us-east-1 and us-west-2 used the same `10.0.0.0/16`, which cannot be routed over an inter-region Transit Gateway. us-west-2 now uses placeholder non-overlapping CIDRs. |
| 5 | High | Bottlerocket nodes have a second data volume (`/dev/xvdb`) that was not encrypted with the CMK. Launch template now maps and encrypts it. **This replaces the node launch template version (rolling node update).** |
| 6 | High | CI hard-coded one lab AWS role. Role is now chosen per environment from `AWS_ROLE_ARN_<ENV>` CI/CD variables (falls back to the lab role). |
| 7 | Medium | S3 recording bucket: Object Lock mode is now a variable (was hard-coded COMPLIANCE for every environment); added TLS-only bucket policy. |
| 8 | Medium | KMS key policy used the CI session ARN (changes every run, causing a policy diff on every apply). Now uses the underlying role/user ARN. |
| 9 | Medium | Route 53 module only supported `continent`, which cannot split east/west inside the US. Added `country` / `subdivision`. |
| 11 | Blocker | No EKS add-ons: `create_efs = true` made the file system but nothing installed a CSI driver, so PVCs could not mount. Added managed add-ons (VPC CNI, CoreDNS, kube-proxy, EBS CSI, and EFS CSI when `create_efs = true`) with IRSA roles; the EBS CSI role also gets the CMK. Pin versions with `addon_versions` in prod. |
| 12 | Blocker | East-region CIDRs all `10.0.0.0/16`. Now unique per environment and region (`10.10` dev, `10.20` qa, `10.30` staging, `10.40` prod; `10.11/.21/.41` for us-west-2). **Placeholders; replace with the client IPAM.** Changing the CIDR of an already-deployed VPC replaces the VPC and the cluster. |
| 13 | High | Added the LiveKit Egress IRSA role (S3 write on the recording bucket + CMK). Namespace / service account default to `livekit` / `livekit-egress`; confirm with the LiveKit deployment. Output: `livekit_egress_role_arn`. |
| 14 | High | Transit Gateway wired in behind `enable_transit_gateway` (default off): TGW + VPC attachment + `aws_route` entries in the root for every private route table towards `tgw_destination_cidrs`. The routes live in the root, not in `modules/vpc`, because the TGW module consumes VPC outputs (passing the TGW id back into the VPC module would be a dependency cycle). |
| 15 | High | Hard-coded lab admin ARN removed from every tfvars (`admin_principal_arns = []`); the CI role that runs apply is already cluster-admin. Client IAM Identity Center role goes here. |
| 16 | High | ALB controller: 2 replicas in staging / prod. |
| 19 | Blocker | First plan failed: `data.aws_eks_cluster` tried to read a cluster that does not exist yet. Kubernetes/Helm providers now use the EKS module outputs plus `aws eks get-token` (exec auth, always-fresh token); the pipeline installs the AWS CLI for it. |
| 20 | Blocker | First plan failed: `modules/iam` used `count` on values only known after apply (OIDC ARN, inline policy JSON). It now takes the booleans `irsa_enabled` and `create_inline_policy`. |
| 21 | Blocker | First apply: the Helm install of the ALB controller failed (`Kubernetes cluster unreachable ... aws exit 255`). The pipeline now exchanges the OIDC token for 1-hour AWS session credentials once at job start (the CLI no longer re-uses a possibly-expired token). The `exit 255` was most likely the AWS CLI itself being broken in the `hashicorp/terraform` image (Alpine `python3` needs a newer `libexpat`: `pyexpat ... XML_SetAllocTrackerActivationThreshold: symbol not found`); the pipeline now upgrades `expat` when installing the CLI and checks `aws --version`, prints the assumed identity, and the Helm release waits for VPC CNI, kube-proxy and CoreDNS (timeout 600 s). |
| 22 | Blocker | A GitLab.com shared runner cannot reach a private-only EKS API, so Terraform cannot install the ALB controller. **Dev only (lab):** `endpoint_public_access = true` (IAM-authenticated, CIDRs via `endpoint_public_access_cidrs`, default `0.0.0.0/0`). qa / staging / prod stay private and need a self-hosted runner or ArgoCD. |
| 23 | High | The ALB controller IAM policy was a hand-copied subset: 7 actions missing versus the official controller v2.14.0 policy (`ec2:DescribeRouteTables`, `ec2:GetSecurityGroupsForVpc`, `elasticloadbalancing:SetRulePriorities`, `...CapacityReservation`, `...IpPools`, `ec2:DescribeIpamPools`). Now loaded from `modules/eks/alb-controller-iam-policy.json` (the official file). Replace that file when `alb_controller_chart_version` changes. |
| 24 | SOW | Added the Stage 2 AWS items that were missing, each behind a flag: VPC flow logs (CMK-encrypted CloudWatch, on by default), CloudTrail (off by default; enable only if no org trail covers the account), Secrets Manager baseline (empty CMK-encrypted containers via `secret_names`), and an Amazon MQ for RabbitMQ broker (off by default, decision pending with Securus). The CMK policy now allows CloudWatch Logs and CloudTrail. Dev enables all four to test. RabbitMQ queue topology (DLQ / retry / replay) is **not** created: it must be applied from inside the VPC. |
| 25 | Design | Private-API access model: optional SSM-only bastion (`enable_bastion`). EC2 (`t2.small`) in a private subnet, no public IP, no inbound rules, no SSH key, IMDSv2, CMK-encrypted root volume, kubectl/helm preinstalled, kubeconfig created at first login. Its role gets an EKS access entry, and the cluster security group allows 443 only from the bastion's security group. See "Private cluster access via the bastion" below. |
| 18 | Medium | Removed the broad EFS client policy from the node role (EFS CSI uses its own IRSA role). To keep EFS mounts working the generated StorageClass no longer sets the `iam` mount option, so mounts are not IAM-authorized; access control is the EFS security group + access point + TLS. If Securus requires IAM authorization, add `iam` back and give the node plugin credentials. **On an existing cluster, nodes lose the policy on apply; remount EFS volumes after the StorageClass change.** |
| 17 | Medium | `nat_gateway_per_az` (one NAT and private route table per AZ), on in staging / prod and passed to `module.vpc` (an earlier build declared it but never passed it, so it had no effect). A `moved` block keeps the existing route table in state. |
| 10 | Low | Added `ec2` interface endpoint; added `Describe/ModifyListenerAttributes` to the ALB controller IAM policy (needed by chart 1.14); formatted `eks-cluster/` so the pipeline's `fmt -check` passes. |

## Private cluster access via the bastion

With `endpoint_public_access = false` the Kubernetes API has no public address. The only door is a jump host inside the VPC:

```
you (browser / aws cli)
   |  AWS Systems Manager Session Manager (IAM-authenticated, logged; no SSH, no open ports)
   v
bastion EC2 (private subnet, no public IP)
   |  HTTPS 443, allowed only from the bastion security group
   v
EKS private API endpoint  (control-plane ENIs in the private subnets)
```

Connect: EC2 console > the bastion > **Connect > Session Manager**, or `aws ssm start-session --target <bastion_instance_id>` (needs the Session Manager plugin; CloudShell does not have it, use the console). On first login the kubeconfig is created automatically, then `kubectl get nodes`.

NAT-less environments: with `enable_nat_gateway = false` the SSM, SSM-messages and EC2-messages interface endpoints are created automatically (the bastion needs them), but kubectl and helm are downloaded at first boot, so mirror them or bake an AMI.

**The GitLab.com shared runner still cannot reach a private API.** The bastion is for people. For pipelines use a self-hosted runner in the VPC (it can run on a bastion-like instance) or install the controller through ArgoCD. Do not flip an environment to private while its state contains a Helm release and the pipeline still runs on the shared runner: plan/apply would time out on the refresh.

## Known gaps (need Securus input or a design decision)

- **Private EKS API vs pipeline (dev worked around, others open).** `dev.tfvars` now uses a public, IAM-authenticated endpoint so the shared runner can install the ALB controller; this is a lab shortcut and must not be copied to the client environments. All tfvars set `endpoint_public_access = false`, but the root module installs the ALB controller with the Helm/Kubernetes providers from the pipeline. A GitLab.com shared runner cannot reach a private API endpoint, so `apply` will time out. Options: a self-hosted runner inside or peered to the VPC (then add a runner `tags:` entry to `.gitlab-ci.yml`), or remove the Helm release from Terraform and install the controller through ArgoCD. Not changed because it needs a decision.
- **Transit Gateway is half-built.** The peering accepter and the TGW static route to the peer CIDR must be created in the other region's stack (different provider region); not included.
- **Route 53 module** is still not wired in: it needs the hosted zone, the domain and the regional ALB/NLB DNS names (known only after the ingress exists), so it should be a separate apply.
- **`enable_nat_gateway = true` in every environment**, including prod. Review against the CJIS / private-egress design before keeping NAT in prod.
- **EKS add-on IAM model.** The CSI add-ons use IRSA. Move to EKS Pod Identity if the client standardises on it.
- **Node security group** allows all egress, and the WebRTC UDP range is open to the VPC CIDR only. Tighten once the STUNner/NLB design and facility CIDRs are confirmed.
- **Recording retention** (`2555` days in prod) is a placeholder and must come from the client; Object Lock is GOVERNANCE until then.
- **Lab values to replace for Securus accounts:** state bucket `terraform-lab-state-mridulsingh05`, lock table, account tags, and the trust policy in `gitlab-trust-policy.json`.
- Variable default `kubernetes_version = "1.31"` is out of standard support; tfvars override it with 1.36.

# aws-terraform-lab

AWS EKS with a Customer Managed Key (CMK) covering etcd secrets, node EBS
volumes, and EFS — deployed with Terraform, state stored in S3 with DynamoDB
locking.

## Repository structure

```
aws-terraform-lab/
├── eks-cluster/                 Root module — wires vpc → kms → efs → eks
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── providers.tf             aws provider + S3 backend
│   ├── backend/                 Backend configs (dev/qa/staging/prod)
│   │   ├── dev.backend.hcl
│   │   ├── qa.backend.hcl
│   │   ├── staging.backend.hcl
│   │   └── prod.backend.hcl
│   └── values/                  Per-environment tfvars
│       ├── dev.tfvars
│       ├── qa.tfvars
│       ├── staging.tfvars
│       └── prod.tfvars
├── modules/                     10 reusable modules — see modules/README.md
│   ├── vpc/                     VPC + subnets + EKS/EFS security groups
│   ├── kms/                     CMK key + alias + key policy
│   ├── efs/                     CMK-encrypted EFS + PostgreSQL access point
│   ├── eks/                     EKS cluster + node groups + OIDC/IRSA provider
│   ├── ec2/                     (available) generic EC2 instance, e.g. a bastion
│   ├── rds/                     (available) generic RDS instance
│   ├── s3/                      (available) generic S3 bucket
│   ├── elasticache/             (available) Redis / Memcached
│   ├── iam/                     (available) generic IAM role, incl. IRSA mode
│   └── security-group/          (available) generic security group
├── setup-s3-backend.sh          One-time S3 + DynamoDB + IAM backend setup
├── cleanup-s3-backend.sh        Tears down the backend resources above
├── .gitlab-ci.yml               GitLab CI/CD pipeline (plan / manual apply / manual destroy)
└── README.md
```

`vpc`, `kms`, `efs`, and `eks` are wired together by `eks-cluster/main.tf`.
The other 6 modules are general-purpose and not wired into anything yet —
compose them into new root configurations later (a bastion, a database, a
cache layer, extra buckets, scoped IRSA roles) without new boilerplate. See
`modules/README.md` for the full reference, including how to use `iam`'s
IRSA mode with `eks`'s OIDC outputs.

## What's encrypted with the CMK

| Resource | How |
|---|---|
| EKS etcd secrets | `encryption_config` on the cluster, `resources = ["secrets"]` |
| EBS node root volumes | `aws_launch_template` block device, `kms_key_id = module.kms.key_arn` |
| EFS file system (PostgreSQL PVC) | `kms_key_id` on the EFS file system |

The KMS key policy (in `modules/kms`) grants access to the root account, the
Terraform deployer, `eks.amazonaws.com`, `elasticfilesystem.amazonaws.com`,
`ec2.amazonaws.com`, the AutoScaling service-linked role, and the exact EKS
node IAM role — the last one is passed in from `eks-cluster/main.tf` as
`local.node_role_name` and fed into **both** the `kms` and `eks` modules, so
the key policy can never reference a role name that doesn't match what `eks`
actually creates. Belt-and-suspenders: `modules/eks` also creates explicit
`aws_kms_grant` resources for the node role and the AutoScaling
service-linked role, in case of IAM/KMS policy propagation delays.

## Backend

State lives in S3 with DynamoDB locking, one state file per environment
**and per region**:

```
s3://terraform-lab-state-mridulsingh05/eks-cluster/<env>/terraform.tfstate         # us-east-1
s3://terraform-lab-state-mridulsingh05/eks-cluster/<env>-usw2/terraform.tfstate    # us-west-2
```

If the bucket/table don't exist yet:

```bash
bash setup-s3-backend.sh
```

If they already exist (check S3 and DynamoDB in the console first), skip
straight to `terraform init`.

## Running it locally

```bash
cd eks-cluster
terraform init -backend-config="backend/dev.backend.hcl"
terraform plan  -var-file="values/dev.tfvars"
terraform apply -var-file="values/dev.tfvars"
```

## Running it via GitLab CI/CD

This pipeline **only runs when manually triggered** — pushing or merging
code does not start it. Trigger from **CI/CD → Pipelines → Run pipeline**
and set the `Environment` and `Action` dropdowns in the **Inputs** box
(`dev`/`qa`/`staging`/`prod`/`dev-usw2`/`qa-usw2`/`prod-usw2` and
`plan`/`apply`/`destroy`/`state`; `state` is read-only and prints how many resources Terraform manages for that environment). Set the CI/CD variables `AWS_ROLE_ARN_DEV`,
`AWS_ROLE_ARN_QA`, `AWS_ROLE_ARN_STAGING`, `AWS_ROLE_ARN_PROD`,
`AWS_ROLE_ARN_DEV_USW2`, `AWS_ROLE_ARN_QA_USW2` and `AWS_ROLE_ARN_PROD_USW2`
to the OIDC role of the matching AWS account; an unset variable falls back to
the original lab role.

- Nothing runs on `git push`, merge requests, or a schedule — the
  top-level `workflow:` rules in `.gitlab-ci.yml` restrict pipeline
  creation to the `web` (Run pipeline button) and `api` sources only.
- `plan` always runs first and is what you review (download `plan.txt` from
  its artifacts, or read the job log).
- Selecting `ACTION=apply` or `ACTION=destroy` does **not** change anything
  by itself — it only makes a manual `apply`/`destroy` job appear, which you
  still have to open the pipeline and click ▶ on.
- `apply` reuses the exact `tfplan` artifact the `plan` job produced —
  never a fresh, unreviewed plan. `destroy` gets its own reviewable
  `terraform plan -destroy` first, via a separate `destroy_plan` job.

### Authentication — OIDC (recommended, no long-lived keys)

The pipeline authenticates to AWS via GitLab's native OIDC support and an
IAM role — no `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` stored in GitLab at
all. Run this once, from a machine with AWS CLI access to your account
(IAM admin permissions needed to create the OIDC provider and role).

**Step 1 — Get your AWS account ID.**

```bash
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "$AWS_ACCOUNT_ID"
```

**Step 2 — Register gitlab.com as an OIDC identity provider in IAM.**

```bash
THUMBPRINT=$(echo | openssl s_client -servername gitlab.com -showcerts -connect gitlab.com:443 2>/dev/null \
  | openssl x509 -fingerprint -sha1 -noout | sed 's/^.*=//;s/://g' | tr 'A-Z' 'a-z')

aws iam create-open-id-connect-provider \
  --url "https://gitlab.com" \
  --client-id-list "https://gitlab.com" \
  --thumbprint-list "$THUMBPRINT"
```

Verify it was created:

```bash
aws iam list-open-id-connect-providers
# should show: arn:aws:iam::<AWS_ACCOUNT_ID>:oidc-provider/gitlab.com
```

**Step 3 — Write the role's trust policy**, scoped to only this project on
the `main` branch (adjust `project_path` if your namespace/repo name differs
from `automation-group5781029/aws-terraform-lab`):

```bash
cat > gitlab-trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Federated": "arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/gitlab.com" },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": { "gitlab.com:aud": "https://gitlab.com" },
      "StringLike":   { "gitlab.com:sub": "project_path:automation-group5781029/aws-terraform-lab:ref_type:branch:ref:main" }
    }
  }]
}
EOF
```

`gitlab.com:sub` is what actually scopes the role — `ref_type:branch:ref:main`
means only pipelines running on `main` can assume it. To also require the
branch be *protected* in GitLab (not just named `main`), add
`"gitlab.com:ref_protected": "true"` to the `StringEquals` block. To allow
any branch instead, change `ref:main` to `ref:*`.

**Step 4 — Create the role from that trust policy.**

```bash
aws iam create-role \
  --role-name gitlab-aws-terraform-lab-oidc \
  --assume-role-policy-document file://gitlab-trust-policy.json
```

**Step 5 — Attach a permissions policy** (what the role is *allowed to do*
once assumed — separate from the trust policy, which controls *who can
assume it*):

```bash
aws iam attach-role-policy \
  --role-name gitlab-aws-terraform-lab-oidc \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess  # lab scope; tighten for real use
```

Verify:

```bash
aws iam get-role --role-name gitlab-aws-terraform-lab-oidc
aws iam list-attached-role-policies --role-name gitlab-aws-terraform-lab-oidc
```

**Step 6 — Put the role ARN into `.gitlab-ci.yml`.** In `.terraform_base`,
replace the placeholder:

```yaml
- export AWS_ROLE_ARN="arn:aws:iam::<AWS_ACCOUNT_ID>:role/gitlab-aws-terraform-lab-oidc"
```

with your real account ID (the value you printed in Step 1), commit, and
push.

**Step 7 — Remove the old static credentials from GitLab**, if you'd set
them: **Settings → CI/CD → Variables** → delete `AWS_ACCESS_KEY_ID` and
`AWS_SECRET_ACCESS_KEY`. Nothing in the pipeline reads them anymore.

**Step 8 — Verify end to end.** Run the pipeline (`CI/CD → Pipelines → Run
pipeline`, `Action = plan`). Open the `plan` job's log — the `terraform
init` line talks to the S3 backend first, so if the OIDC → role exchange is
broken, you'll see an auth error right there rather than deeper into the run.
A clean `Terraform has been successfully initialized!` confirms the role
assumption worked.

<details>
<summary>Alternative — static access keys (what earlier revisions of this pipeline used)</summary>

| Variable | Used for |
|---|---|
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | S3/DynamoDB backend access **and** all AWS resource provisioning |

Set these in **Settings → CI/CD → Variables** (masked + protected) and skip
the OIDC setup above. Works, but means a long-lived key pair sits in GitLab
indefinitely — prefer OIDC where possible.
</details>

## Node pool design

| Pool | Purpose | Taint | Notes |
|---|---|---|---|
| System | kube-system components only | `CriticalAddonsOnly=true:NoSchedule` | Disabled by default (`enable_system_node_group = false` in `dev.tfvars`) to save cost |
| User | App + PostgreSQL pods | None | Always created |

Set `enable_system_node_group = true` in `staging.tfvars`/`prod.tfvars` for
a proper system/user split.

## Verify CMK is working

```bash
# EKS etcd encryption
aws eks describe-cluster --name eks-dev-cluster --region us-east-1 \
  --query "cluster.encryptionConfig[].{Resources:resources,KeyArn:provider.keyArn}" --output table

# KMS key status
aws kms describe-key --key-id alias/eks-dev-cmk --region us-east-1 \
  --query "KeyMetadata.{KeyId:KeyId,State:KeyState}" --output table

# EBS volumes encrypted
aws ec2 describe-volumes --region us-east-1 \
  --filters "Name=tag:eks:cluster-name,Values=eks-dev-cluster" \
  --query "Volumes[].{ID:VolumeId,Encrypted:Encrypted,KmsKeyId:KmsKeyId}" --output table

# EFS encrypted
aws efs describe-file-systems --region us-east-1 \
  --query "FileSystems[].{ID:FileSystemId,Encrypted:Encrypted,KmsKeyId:KmsKeyId}" --output table
```

## Deploying a sample app (NodePort)

`eks-cluster/k8s-manifests/demo-app.yaml` has a Deployment (2 replicas,
`nginxdemos/hello`) + a `NodePort` Service on port `30080`:

```bash
kubectl apply -f eks-cluster/k8s-manifests/demo-app.yaml
kubectl get deployment,pods,svc -l app=demo-app
```

**Reachability — read this before expecting it to load in a browser.**
Nodes are in private subnets with no public IP (`endpoint_public_access`
controls the *EKS API* endpoint, not node reachability), so a NodePort
Service is only reachable from **inside the VPC** — the node security
group's NodePort ingress rule (added in `modules/vpc`) is scoped to
`var.vpc_cidr`, not the internet. Pick one:

- **`kubectl port-forward`** — zero extra infra, works right now over the
  same connection `kubectl get nodes` already uses:
  ```bash
  kubectl port-forward svc/demo-app 8080:80
  # then open http://localhost:8080
  ```
- **A bastion/jump host inside the VPC** — launch one with the `ec2` module
  (public subnet, SG allowing your IP), then from it:
  ```bash
  # node's private IP, from:
  kubectl get nodes -o wide
  curl http://<node-private-ip>:30080
  ```
- **Switch the Service to `type: LoadBalancer`** instead of NodePort if you
  actually want a stable internet-facing (or internal) endpoint — AWS
  provisions a Network Load Balancer for you. Bigger change than what was
  asked for here, but worth knowing it's the usual answer to "how do
  external users reach this."

## Getting `kubectl` access to the cluster

By default, **only the IAM principal that ran `terraform apply`** (the
GitLab OIDC role, `gitlab-aws-terraform-lab-oidc`) can talk to the
Kubernetes API — not your own IAM user, even with `AdministratorAccess` on
the AWS account. This is Kubernetes-level RBAC, a separate layer from IAM
permissions to call the EKS *API* (which is why you can see the cluster
fine in the console but `kubectl`/CloudShell says `Unauthorized`).

`modules/eks` sets `access_config { authentication_mode =
"API_AND_CONFIG_MAP" }` and creates an
[EKS access entry](https://docs.aws.amazon.com/eks/latest/userguide/access-entries.html)
for every ARN listed in `admin_principal_arns`. To get access:

1. Find your ARN: `aws sts get-caller-identity --query Arn --output text`
2. Add it to `admin_principal_arns` in `values/<env>.tfvars`:
   ```hcl
   admin_principal_arns = [
     "arn:aws:iam::730335612245:user/your-username",
   ]
   ```
3. Run the pipeline again with `Action=apply`.
4. Connect: `aws eks update-kubeconfig --name eks-dev-cluster --region us-east-1`
   (or `source kubectl-connect eks-dev-cluster` from CloudShell), then
   `kubectl get nodes`.

The applying principal (the GitLab role) keeps its access automatically via
`bootstrap_cluster_creator_admin_permissions = true` — you don't need to add
it to this list.

## After apply — Kubernetes StorageClass

`modules/efs` writes an EFS CSI StorageClass manifest to
`eks-cluster/k8s-manifests/efs-postgres-storageclass.yaml`. Install the EFS
CSI driver on the cluster, then:

```bash
kubectl apply -f eks-cluster/k8s-manifests/efs-postgres-storageclass.yaml
```

## Destroy / cleanup

```bash
# via CI/CD: Run pipeline with ACTION=destroy, then click ▶ on the destroy job

# or locally
cd eks-cluster
terraform destroy -var-file="values/dev.tfvars"
```

KMS keys have a minimum 7-day deletion waiting period if you also want to
remove the CMK itself:

```bash
aws kms schedule-key-deletion --key-id alias/eks-dev-cmk --pending-window-in-days 7 --region us-east-1
aws kms delete-alias --alias-name alias/eks-dev-cmk --region us-east-1
```

To remove the backend itself (S3 bucket, DynamoDB table, IAM user):

```bash
bash cleanup-s3-backend.sh
```
