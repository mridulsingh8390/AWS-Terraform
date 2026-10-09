# Dragonfly Update - Changes Applied

The original EKS lab ZIP was updated toward the supplied Project Dragonfly SOW / Change Request.

## Changes
- Added Bottlerocket FIPS AMI controls to EKS managed node groups.
- Added private AWS VPC endpoint module.
- Added Dragonfly LiveKit recording S3 module with KMS/Object Lock/lifecycle controls.
- Added WebRTC/STUN and configurable SIP security-group rules.
- Added reusable Route 53 geolocation + health-check module.
- Added reusable inter-region Transit Gateway module.
- Added private EKS API defaults to environment tfvars.
- Added Dragonfly environment/account/compliance tags.
- Added configurable NAT behavior.
- Preserved existing ALB controller, EFS, KMS, IAM and EKS access functionality.

## Deliberately left as inputs/dependencies
- Securus facility/SBC CIDRs.
- Securus private PKI / mTLS implementation.
- Approved Chainguard registry/image references.
- RabbitMQ deployment and DLQ/replay topology.
- Splunk/SIEM integration details.
- Route 53 hosted zone/domain and regional ALB identifiers.
- Inter-region TGW ownership/peering IDs.
- Final RTO/RPO/SLO and recording retention policy.

These items require client/platform decisions identified in the supplied project documents and should not be fabricated in Terraform.

---

# Validation pass (second update)

See "Validation pass (what was fixed)" and "Known gaps" in `README.md` for the full table. Summary: fixed HCL syntax
errors that stopped `terraform validate`, separated us-west-2 state/CI/CIDRs, encrypted the Bottlerocket data volume with
the CMK, made Object Lock mode and the CI role per-environment, and stabilised the KMS key policy.

## Third update: EKS review findings

Added EKS managed add-ons and CSI drivers (with IRSA), LiveKit Egress IRSA role, unique placeholder CIDRs, per-AZ NAT,
Transit Gateway wiring (off by default), 2 ALB controller replicas for staging/prod, and removed the hard-coded lab admin
ARN outside `dev`. The private-API / shared-runner problem is documented but not changed (needs a decision).
