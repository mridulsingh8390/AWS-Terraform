#!/bin/bash
# =============================================================================
# Terraform S3 Backend Setup Script
# Creates: S3 bucket, DynamoDB lock table, IAM user + policy + access keys
#
# Usage:
#   1. Edit BUCKET_NAME and REGION below
#   2. Run: bash setup-s3-backend.sh
# =============================================================================

BUCKET_NAME="terraform-lab-state-mridulsingh05"   # must be globally unique
REGION="us-east-1"
TABLE_NAME="terraform-state-lock"
IAM_USER="terraform-state-user"

# Colours for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Colour

ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; exit 1; }

# =============================================================================
# 1. S3 Bucket
# =============================================================================
echo ""
echo "=== Step 1: Creating S3 bucket ==="

# us-east-1 is the default AWS region — it must NOT include
# --create-bucket-configuration. Every other region requires it.
if [ "$REGION" = "us-east-1" ]; then
  aws s3api create-bucket \
    --bucket "$BUCKET_NAME" \
    --region "$REGION" \
    --output text > /dev/null && ok "Bucket created: $BUCKET_NAME" || fail "Failed to create bucket"
else
  aws s3api create-bucket \
    --bucket "$BUCKET_NAME" \
    --region "$REGION" \
    --create-bucket-configuration LocationConstraint="$REGION" \
    --output text > /dev/null && ok "Bucket created: $BUCKET_NAME" || fail "Failed to create bucket"
fi

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket "$BUCKET_NAME" \
  --versioning-configuration Status=Enabled && ok "Versioning enabled" || fail "Failed to enable versioning"

# Block all public access
aws s3api put-public-access-block \
  --bucket "$BUCKET_NAME" \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true \
  && ok "Public access blocked" || fail "Failed to block public access"

# Enable AES-256 encryption
aws s3api put-bucket-encryption \
  --bucket "$BUCKET_NAME" \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}
    }]
  }' && ok "Encryption enabled" || fail "Failed to enable encryption"

# =============================================================================
# 2. DynamoDB lock table
# =============================================================================
echo ""
echo "=== Step 2: Creating DynamoDB lock table ==="

aws dynamodb create-table \
  --table-name "$TABLE_NAME" \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region "$REGION" \
  --output text > /dev/null && ok "DynamoDB table created: $TABLE_NAME" || fail "Failed to create DynamoDB table"

# =============================================================================
# 3. IAM user + policy + access keys
# =============================================================================
echo ""
echo "=== Step 3: Creating IAM user ==="

aws iam create-user \
  --user-name "$IAM_USER" \
  --output text > /dev/null && ok "IAM user created: $IAM_USER" || fail "Failed to create IAM user"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

aws iam put-user-policy \
  --user-name "$IAM_USER" \
  --policy-name TerraformStateAccess \
  --policy-document "{
    \"Version\": \"2012-10-17\",
    \"Statement\": [
      {
        \"Effect\": \"Allow\",
        \"Action\": [
          \"s3:GetObject\",
          \"s3:PutObject\",
          \"s3:DeleteObject\",
          \"s3:ListBucket\"
        ],
        \"Resource\": [
          \"arn:aws:s3:::${BUCKET_NAME}\",
          \"arn:aws:s3:::${BUCKET_NAME}/*\"
        ]
      },
      {
        \"Effect\": \"Allow\",
        \"Action\": [
          \"dynamodb:GetItem\",
          \"dynamodb:PutItem\",
          \"dynamodb:DeleteItem\"
        ],
        \"Resource\": \"arn:aws:dynamodb:${REGION}:${ACCOUNT_ID}:table/${TABLE_NAME}\"
      }
    ]
  }" && ok "IAM policy attached" || fail "Failed to attach IAM policy"

echo ""
echo "=== Step 4: Creating access keys ==="
echo "(Save these — shown only once)"
echo ""

aws iam create-access-key --user-name "$IAM_USER"

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "============================================="
echo " Setup complete. Add these to GitHub Secrets:"
echo "============================================="
echo "  TF_STATE_BUCKET       = $BUCKET_NAME"
echo "  TF_STATE_LOCK_TABLE   = $TABLE_NAME"
echo "  AWS_REGION            = $REGION"
echo "  AWS_ACCESS_KEY_ID     = (AccessKeyId from above)"
echo "  AWS_SECRET_ACCESS_KEY = (SecretAccessKey from above)"
echo ""
echo "  NOTE: Rotate the access keys after adding them to"
echo "  GitHub — never leave them visible in terminal output."
echo "============================================="
