#!/bin/bash

set -e

echo "========================================"
echo "AWS 3-Tier HA Platform - Pre-Deployment Validation"
echo "========================================"
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

VALIDATION_FAILED=0

# 1. Check AWS CLI Installation
echo "[1/10] Checking AWS CLI installation..."
if ! command -v aws &> /dev/null; then
    echo -e "${RED}✗ AWS CLI not found. Install it first.${NC}"
    VALIDATION_FAILED=1
else
    echo -e "${GREEN}✓ AWS CLI found${NC}"
fi

# 2. Check Terraform Installation
echo "[2/10] Checking Terraform installation..."
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}✗ Terraform not found. Install it first.${NC}"
    VALIDATION_FAILED=1
else
    TF_VERSION=$(terraform version -json 2>/dev/null | grep terraform_version | cut -d'"' -f4 || terraform version | grep Terraform | awk '{print $2}')
    echo -e "${GREEN}✓ Terraform found (version: $TF_VERSION)${NC}"
fi

# 3. Check AWS Credentials
echo "[3/10] Checking AWS credentials..."
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}✗ AWS credentials not configured or invalid.${NC}"
    VALIDATION_FAILED=1
else
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    echo -e "${GREEN}✓ AWS credentials valid (Account: $ACCOUNT_ID)${NC}"
fi

# 4. Check IAM Permissions (Basic)
echo "[4/10] Checking IAM permissions..."
PERMISSION_CHECK=true
aws ec2 describe-regions --region ap-south-1 &> /dev/null || PERMISSION_CHECK=false
aws s3 list-buckets &> /dev/null || PERMISSION_CHECK=false
aws rds describe-db-instances --region ap-south-1 &> /dev/null || PERMISSION_CHECK=false
aws dynamodb list-tables --region ap-south-1 &> /dev/null || PERMISSION_CHECK=false

if $PERMISSION_CHECK; then
    echo -e "${GREEN}✓ IAM permissions sufficient (EC2, S3, RDS, DynamoDB)${NC}"
else
    echo -e "${YELLOW}⚠ Some IAM permissions may be limited${NC}"
fi

# 5. Check S3 Backend Bucket Exists
echo "[5/10] Checking S3 backend bucket..."
BUCKET_NAME="aws-3tier-ha-tfstate-${ACCOUNT_ID}"
if aws s3api head-bucket --bucket "$BUCKET_NAME" --region ap-south-1 2>/dev/null; then
    echo -e "${GREEN}✓ S3 backend bucket exists ($BUCKET_NAME)${NC}"
else
    echo -e "${RED}✗ S3 backend bucket does not exist. Run bootstrap/terraform apply first.${NC}"
    VALIDATION_FAILED=1
fi

# 6. Check DynamoDB Table Exists (Fixed - with retry logic)
echo "[6/10] Checking DynamoDB state lock table..."
TABLE_NAME="aws-3tier-ha-tfstate-lock"
MAX_RETRIES=3
RETRY_COUNT=0
TABLE_EXISTS=false

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if aws dynamodb describe-table --table-name "$TABLE_NAME" --region ap-south-1 &> /dev/null; then
        TABLE_EXISTS=true
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
        sleep 2
    fi
done

if $TABLE_EXISTS; then
    echo -e "${GREEN}✓ DynamoDB state lock table exists ($TABLE_NAME)${NC}"
else
    echo -e "${RED}✗ DynamoDB state lock table does not exist. Run: cd bootstrap && terraform apply${NC}"
    VALIDATION_FAILED=1
fi

# 7. Check Terraform Files Syntax
echo "[7/10] Validating Terraform files..."
if terraform -chdir=environments/dev validate &> /dev/null; then
    echo -e "${GREEN}✓ Terraform files syntax valid${NC}"
else
    echo -e "${RED}✗ Terraform files have syntax errors${NC}"
    terraform -chdir=environments/dev validate
    VALIDATION_FAILED=1
fi

# 8. Check Variable File Exists
echo "[8/10] Checking terraform.tfvars file..."
if [ -f "environments/dev/terraform.tfvars" ]; then
    echo -e "${GREEN}✓ terraform.tfvars found${NC}"
else
    echo -e "${RED}✗ terraform.tfvars not found in environments/dev/${NC}"
    VALIDATION_FAILED=1
fi

# 9. Check Required Variables
echo "[9/10] Validating required variables..."
REQUIRED_VARS=("project_name" "vpc_cidr" "ami_id" "db_username" "db_password")
TFVARS_FILE="environments/dev/terraform.tfvars"

for var in "${REQUIRED_VARS[@]}"; do
    if grep -q "^${var}" "$TFVARS_FILE"; then
        echo -e "${GREEN}✓ $var configured${NC}"
    else
        echo -e "${RED}✗ $var not found in terraform.tfvars${NC}"
        VALIDATION_FAILED=1
    fi
done

# 10. Check AWS Region Availability
echo "[10/10] Checking AWS region availability..."
REGION="ap-south-1"
if aws ec2 describe-availability-zones --region "$REGION" &> /dev/null; then
    echo -e "${GREEN}✓ Region $REGION is accessible${NC}"
else
    echo -e "${RED}✗ Region $REGION is not accessible${NC}"
    VALIDATION_FAILED=1
fi

echo ""
echo "========================================"
if [ $VALIDATION_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓✓✓ All validations passed! Ready for deployment. ✓✓✓${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. cd environments/dev/"
    echo "  2. terraform init"
    echo "  3. terraform plan -var-file=terraform.tfvars"
    echo "  4. Review the plan output"
    echo "  5. Commit and push to GitHub to trigger GitHub Actions"
    exit 0
else
    echo -e "${RED}✗ Some validations failed. Fix issues before proceeding.${NC}"
    exit 1
fi
