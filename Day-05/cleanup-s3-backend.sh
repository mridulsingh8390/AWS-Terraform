#!/bin/bash
# =============================================================================
# Terraform S3 Backend Cleanup Script
# Deletes: S3 bucket (all versions + delete markers), DynamoDB table,
#          IAM user access keys + policy + user
#
# Usage:
#   bash cleanup-s3-backend.sh
# =============================================================================

BUCKET_NAME="terraform-lab-state-mridulsingh05"
REGION="us-east-1"
TABLE_NAME="terraform-state-lock"
IAM_USER="terraform-state-user"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[SKIP]${NC} $1"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; }

# =============================================================================
# 1. S3 Bucket — must delete all object versions before bucket can be deleted
# =============================================================================
echo ""
echo "=== Step 1: Deleting S3 bucket and all versions ==="

# Delete all object versions (required when versioning is enabled)
VERSIONS=$(aws s3api list-object-versions \
  --bucket "$BUCKET_NAME" \
  --query 'Versions[].{Key:Key,VersionId:VersionId}' \
  --output json 2>/dev/null)

if [ "$VERSIONS" != "null" ] && [ -n "$VERSIONS" ] && [ "$VERSIONS" != "[]" ]; then
  echo "$VERSIONS" | \
  python3 -c "
import json, sys, subprocess
items = json.load(sys.stdin)
for item in items:
    subprocess.run(['aws','s3api','delete-object',
      '--bucket','$BUCKET_NAME',
      '--key', item['Key'],
      '--version-id', item['VersionId']], check=False)
  " && ok "All object versions deleted" || warn "No object versions to delete"
else
  warn "No object versions found"
fi

# Delete all delete markers
MARKERS=$(aws s3api list-object-versions \
  --bucket "$BUCKET_NAME" \
  --query 'DeleteMarkers[].{Key:Key,VersionId:VersionId}' \
  --output json 2>/dev/null)

if [ "$MARKERS" != "null" ] && [ -n "$MARKERS" ] && [ "$MARKERS" != "[]" ]; then
  echo "$MARKERS" | \
  python3 -c "
import json, sys, subprocess
items = json.load(sys.stdin)
for item in items:
    subprocess.run(['aws','s3api','delete-object',
      '--bucket','$BUCKET_NAME',
      '--key', item['Key'],
      '--version-id', item['VersionId']], check=False)
  " && ok "All delete markers removed" || warn "No delete markers to remove"
else
  warn "No delete markers found"
fi

# Now delete the empty bucket
aws s3api delete-bucket \
  --bucket "$BUCKET_NAME" \
  --region "$REGION" \
  && ok "Bucket deleted: $BUCKET_NAME" || fail "Failed to delete bucket (may not exist or already deleted)"

# =============================================================================
# 2. DynamoDB table
# =============================================================================
echo ""
echo "=== Step 2: Deleting DynamoDB table ==="

aws dynamodb delete-table \
  --table-name "$TABLE_NAME" \
  --region "$REGION" \
  --output text > /dev/null \
  && ok "DynamoDB table deleted: $TABLE_NAME" \
  || fail "Failed to delete DynamoDB table (may not exist)"

# =============================================================================
# 3. IAM — access keys → inline policy → user
# =============================================================================
echo ""
echo "=== Step 3: Deleting IAM user, policy, and access keys ==="

# Delete all access keys first (user cannot be deleted with active keys)
KEYS=$(aws iam list-access-keys \
  --user-name "$IAM_USER" \
  --query 'AccessKeyMetadata[].AccessKeyId' \
  --output text 2>/dev/null)

if [ -n "$KEYS" ]; then
  for KEY_ID in $KEYS; do
    aws iam delete-access-key \
      --user-name "$IAM_USER" \
      --access-key-id "$KEY_ID" \
      && ok "Access key deleted: $KEY_ID" || fail "Failed to delete key: $KEY_ID"
  done
else
  warn "No access keys found for $IAM_USER"
fi

# Delete inline policy
aws iam delete-user-policy \
  --user-name "$IAM_USER" \
  --policy-name TerraformStateAccess \
  && ok "Inline policy deleted" || warn "Policy not found (may already be deleted)"

# Delete user
aws iam delete-user \
  --user-name "$IAM_USER" \
  && ok "IAM user deleted: $IAM_USER" || fail "Failed to delete IAM user"

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "============================================="
echo " Cleanup complete. Deleted:"
echo "   S3 bucket    : $BUCKET_NAME"
echo "   DynamoDB     : $TABLE_NAME"
echo "   IAM user     : $IAM_USER"
echo "============================================="
echo " Remember to remove the GitHub Secrets too:"
echo "   TF_STATE_BUCKET, TF_STATE_LOCK_TABLE,"
echo "   AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY"
echo "============================================="
