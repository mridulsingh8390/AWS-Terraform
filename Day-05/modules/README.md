# modules/ — module index

14 modules total. `vpc`, `kms`, `efs`, `eks`, `vpc-endpoints` and `s3-recording` are wired into
`eks-cluster` today; `transit-gateway` is wired behind `enable_transit_gateway`; `route53-geolocation` is not wired yet (see the
root README "Known gaps"); the other 6 are common/reusable modules available for you to compose into new
root configurations later (a bastion, a database, a cache layer, extra
buckets, scoped IRSA roles, etc.) without writing new module boilerplate.

| Module | Wired into `eks-cluster`? | Purpose |
|---|---|---|
| `vpc` | ✅ | VPC, subnets, EKS/EFS security groups |
| `kms` | ✅ | CMK used for EKS etcd, EBS, EFS encryption |
| `efs` | ✅ | CMK-encrypted EFS + PostgreSQL access point + StorageClass manifest |
| `eks` | ✅ | EKS cluster, node groups, OIDC/IRSA provider |
| `vpc-endpoints` | ✅ (flag) | Private ECR, KMS-FIPS, STS, Logs, Monitoring, Secrets Manager, ELB, EC2 endpoints + S3 gateway endpoint |
| `s3-recording` | ✅ (flag) | LiveKit HLS recording bucket: KMS, versioning, Object Lock (mode configurable), TLS-only policy, Glacier lifecycle |
| `route53-geolocation` | — | Health check + geolocation alias record (continent / country / US state) per region |
| `transit-gateway` | ✅ (flag) | TGW + VPC attachment + optional peering request (accepter and routes not included yet) |
| `ec2` | — | Generic single EC2 instance (e.g. a bastion/jumpbox into the cluster's private subnets) |
| `rds` | — | Generic single RDS instance (Postgres/MySQL/etc.), Secrets-Manager-managed password by default |
| `s3` | — | Generic S3 bucket (versioning, SSE, lifecycle rules) — for buckets beyond the Terraform state bucket |
| `elasticache` | — | Redis replication group or Memcached cluster |
| `iam` | — | Generic IAM role, including an IRSA trust-policy mode for EKS service accounts |
| `security-group` | — | Generic security group with dynamic ingress/egress rule lists |

## Using the IRSA mode of `iam`

To create a scoped IAM role for a Kubernetes service account (instead of
attaching broad node-level policies), feed it the `eks` module's OIDC
outputs:

```hcl
module "irsa_example" {
  source = "../modules/iam"

  role_name = "${var.cluster_name}-example-sa"

  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
  namespace         = "default"
  service_account   = "example-sa"

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess",
  ]

  tags = var.tags
}
```

Note: `module.eks.oidc_provider_url` was added specifically for this — it's
the OIDC issuer with the `https://` prefix stripped, which is the format IRSA
trust-policy conditions require. The pre-existing `cluster_oidc_issuer`
output still returns the full URL, used elsewhere.
