#!/bin/bash

# GitHub Actions CI/CD Setup Script
# This script automates the setup of GitHub Actions for GCP Hello World Infrastructure

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
PROJECT_ID_DEV=""
PROJECT_ID_TEST=""
PROJECT_ID_PROD=""
SA_NAME="github-actions-sa"
KEY_FILE_PREFIX="github-actions"
CREATE_BUCKETS="false"

# Function to print usage
usage() {
    echo "Usage: $0 -d DEV_PROJECT_ID -t TEST_PROJECT_ID -p PROD_PROJECT_ID [OPTIONS]"
    echo ""
    echo "Required:"
    echo "  -d DEV_PROJECT_ID    GCP Project ID for Development environment"
    echo "  -t TEST_PROJECT_ID   GCP Project ID for Test environment"
    echo "  -p PROD_PROJECT_ID   GCP Project ID for Production environment"
    echo ""
    echo "Optional:"
    echo "  -s SA_NAME           Service Account name [default: github-actions-sa]"
    echo "  -k KEY_PREFIX        Key file prefix [default: github-actions]"
    echo "  -b                   Create Terraform state buckets"
    echo "  -h                   Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -d my-dev-project -t my-test-project -p my-prod-project"
    echo "  $0 -d my-dev-project -t my-test-project -p my-prod-project -b"
}

# Function to create service account and assign roles
setup_service_account() {
    local project_id=$1
    local env_suffix=$2
    
    echo -e "${YELLOW}Setting up Service Account for $project_id ($env_suffix)...${NC}"
    
    # Check if project exists and is accessible
    if ! gcloud projects describe "$project_id" >/dev/null 2>&1; then
        echo -e "${RED}Error: Project $project_id does not exist or is not accessible${NC}"
        return 1
    fi
    
    # Set current project
    gcloud config set project "$project_id"
    
    local sa_email="${SA_NAME}@${project_id}.iam.gserviceaccount.com"
    
    # Check if service account already exists
    if gcloud iam service-accounts describe "$sa_email" >/dev/null 2>&1; then
        echo -e "${YELLOW}Service Account already exists: $sa_email${NC}"
    else
        # Create service account
        echo "Creating Service Account: $sa_email"
        if ! gcloud iam service-accounts create "$SA_NAME" \
            --display-name="GitHub Actions Service Account" \
            --description="Service Account for GitHub Actions CI/CD" \
            --project="$project_id"; then
            echo -e "${RED}Failed to create Service Account${NC}"
            return 1
        fi
        
        # Wait a moment for the service account to be fully created
        echo "Waiting for service account to be ready..."
        sleep 10
        
        # Verify service account was created
        if ! gcloud iam service-accounts describe "$sa_email" >/dev/null 2>&1; then
            echo -e "${RED}Service Account creation verification failed${NC}"
            return 1
        fi
        echo -e "${GREEN}Service Account created successfully${NC}"
    fi
    
    # Required roles for the service account
    local roles=(
        "roles/compute.admin"
        "roles/cloudfunctions.admin"
        "roles/storage.admin"
        "roles/iam.serviceAccountUser"
        "roles/serviceusage.serviceUsageAdmin"
        "roles/cloudbuild.builds.editor"
        "roles/logging.admin"
    )
    
    # Assign roles
    echo "Assigning IAM roles to $sa_email..."
    for role in "${roles[@]}"; do
        echo "  - Assigning $role"
        if ! gcloud projects add-iam-policy-binding "$project_id" \
            --member="serviceAccount:$sa_email" \
            --role="$role" \
            --quiet >/dev/null 2>&1; then
            echo -e "${YELLOW}    Warning: Failed to assign $role (may already exist)${NC}"
        else
            echo -e "${GREEN}    ✅ Successfully assigned $role${NC}"
        fi
    done
    
    # Generate service account key
    local key_file="${KEY_FILE_PREFIX}-${env_suffix}.json"
    echo "Generating service account key: $key_file"
    
    # Check if key file already exists
    if [ -f "$key_file" ]; then
        echo -e "${YELLOW}Key file already exists. Creating new key...${NC}"
        mv "$key_file" "${key_file}.backup.$(date +%s)"
    fi
    
    if ! gcloud iam service-accounts keys create "$key_file" \
        --iam-account="$sa_email" \
        --project="$project_id"; then
        echo -e "${RED}Failed to create service account key${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✅ Service Account setup completed for $project_id${NC}"
    echo "   📄 Key file: $key_file"
    echo "   📧 Service Account: $sa_email"
    echo ""
}

# Function to enable required APIs
enable_apis() {
    local project_id=$1
    local env_name=$2
    
    echo -e "${YELLOW}Enabling required APIs for $project_id ($env_name)...${NC}"
    
    gcloud config set project "$project_id"
    
    local apis=(
        "compute.googleapis.com"
        "cloudfunctions.googleapis.com"
        "storage.googleapis.com"
        "logging.googleapis.com"
        "cloudbuild.googleapis.com"
        "iam.googleapis.com"
        "serviceusage.googleapis.com"
    )
    
    for api in "${apis[@]}"; do
        echo "  - Enabling $api"
        if ! gcloud services enable "$api" --project="$project_id" --quiet; then
            echo -e "${YELLOW}    Warning: Failed to enable $api${NC}"
        else
            echo -e "${GREEN}    ✅ Successfully enabled $api${NC}"
        fi
    done
    
    echo -e "${GREEN}✅ API enablement completed for $project_id${NC}"
    echo ""
}

# Function to create Terraform state buckets
create_state_buckets() {
    local project_id=$1
    local env_name=$2
    
    local bucket_name="${project_id}-terraform-state-${env_name}"
    
    echo -e "${YELLOW}Creating Terraform state bucket: $bucket_name${NC}"
    
    gcloud config set project "$project_id"
    
    # Check if bucket already exists
    if gsutil ls "gs://$bucket_name" >/dev/null 2>&1; then
        echo -e "${YELLOW}Bucket $bucket_name already exists${NC}"
    else
        # Create bucket
        if ! gsutil mb "gs://$bucket_name"; then
            echo -e "${RED}Failed to create bucket: $bucket_name${NC}"
            return 1
        fi
        
        # Enable versioning
        if ! gsutil versioning set on "gs://$bucket_name"; then
            echo -e "${YELLOW}Warning: Failed to enable versioning on $bucket_name${NC}"
        fi
        
        echo -e "${GREEN}✅ Bucket created: gs://$bucket_name${NC}"
    fi
    echo ""
}

# Function to display GitHub Secrets configuration
display_secrets_config() {
    echo -e "${BLUE}=== GitHub Secrets Configuration ===${NC}"
    echo ""
    echo "Configure the following secrets in your GitHub repository:"
    echo ""
    echo -e "${YELLOW}Repository Secrets:${NC}"
    
    # Check if key files exist before trying to encode them
    if [ -f "${KEY_FILE_PREFIX}-dev.json" ]; then
        echo "  GCP_SA_KEY_DEV      = $(cat ${KEY_FILE_PREFIX}-dev.json | base64 -w 0 2>/dev/null || cat ${KEY_FILE_PREFIX}-dev.json | base64)"
    else
        echo "  GCP_SA_KEY_DEV      = [KEY FILE NOT FOUND: ${KEY_FILE_PREFIX}-dev.json]"
    fi
    echo "  GCP_PROJECT_ID_DEV  = $PROJECT_ID_DEV"
    echo ""
    
    if [ -f "${KEY_FILE_PREFIX}-test.json" ]; then
        echo "  GCP_SA_KEY_TEST     = $(cat ${KEY_FILE_PREFIX}-test.json | base64 -w 0 2>/dev/null || cat ${KEY_FILE_PREFIX}-test.json | base64)"
    else
        echo "  GCP_SA_KEY_TEST     = [KEY FILE NOT FOUND: ${KEY_FILE_PREFIX}-test.json]"
    fi
    echo "  GCP_PROJECT_ID_TEST = $PROJECT_ID_TEST"
    echo ""
    
    if [ -f "${KEY_FILE_PREFIX}-prod.json" ]; then
        echo "  GCP_SA_KEY_PROD     = $(cat ${KEY_FILE_PREFIX}-prod.json | base64 -w 0 2>/dev/null || cat ${KEY_FILE_PREFIX}-prod.json | base64)"
    else
        echo "  GCP_SA_KEY_PROD     = [KEY FILE NOT FOUND: ${KEY_FILE_PREFIX}-prod.json]"
    fi
    echo "  GCP_PROJECT_ID_PROD = $PROJECT_ID_PROD"
    echo ""
    echo -e "${YELLOW}Optional Secrets:${NC}"
    echo "  INFRACOST_API_KEY   = your-infracost-api-key"
    echo "  PROD_APPROVERS      = user1,user2,user3"
    echo ""
    echo -e "${BLUE}Instructions:${NC}"
    echo "1. Go to your GitHub repository"
    echo "2. Navigate to Settings > Secrets and variables > Actions"
    echo "3. Click 'New repository secret'"
    echo "4. Add each secret with the name and value shown above"
    echo ""
}

# Function to create backend configuration files
create_backend_configs() {
    echo -e "${YELLOW}Creating Terraform backend configuration files...${NC}"
    
    # Development backend
    cat > environments/dev/backend.tf <<EOF
terraform {
  backend "gcs" {
    bucket = "${PROJECT_ID_DEV}-terraform-state-dev"
    prefix = "dev/terraform/state"
  }
}
EOF
    
    # Test backend
    cat > environments/test/backend.tf <<EOF
terraform {
  backend "gcs" {
    bucket = "${PROJECT_ID_TEST}-terraform-state-test"
    prefix = "test/terraform/state"
  }
}
EOF
    
    # Production backend
    cat > environments/prd/backend.tf <<EOF
terraform {
  backend "gcs" {
    bucket = "${PROJECT_ID_PROD}-terraform-state-prd"
    prefix = "prd/terraform/state"
  }
}
EOF
    
    echo -e "${GREEN}✅ Backend configuration files created${NC}"
    echo ""
}

# Parse command line arguments
while getopts "d:t:p:s:k:bh" opt; do
    case $opt in
        d)
            PROJECT_ID_DEV="$OPTARG"
            ;;
        t)
            PROJECT_ID_TEST="$OPTARG"
            ;;
        p)
            PROJECT_ID_PROD="$OPTARG"
            ;;
        s)
            SA_NAME="$OPTARG"
            ;;
        k)
            KEY_FILE_PREFIX="$OPTARG"
            ;;
        b)
            CREATE_BUCKETS="true"
            ;;
        h)
            usage
            exit 0
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            usage
            exit 1
            ;;
    esac
done

# Validate required parameters
if [ -z "$PROJECT_ID_DEV" ] || [ -z "$PROJECT_ID_TEST" ] || [ -z "$PROJECT_ID_PROD" ]; then
    echo -e "${RED}Error: All project IDs are required${NC}"
    usage
    exit 1
fi

echo -e "${GREEN}🚀 Starting GitHub Actions CI/CD Setup${NC}"
echo "=================================="
echo "Development Project: $PROJECT_ID_DEV"
echo "Test Project:        $PROJECT_ID_TEST"
echo "Production Project:  $PROJECT_ID_PROD"
echo "Service Account:     $SA_NAME"
echo "Create Buckets:      $CREATE_BUCKETS"
echo ""

# Check if gcloud is authenticated
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
    echo -e "${RED}Error: Not authenticated with GCP. Please run 'gcloud auth login'${NC}"
    exit 1
fi

# Setup for each environment
echo -e "${BLUE}Setting up Development Environment...${NC}"
setup_service_account "$PROJECT_ID_DEV" "dev"
enable_apis "$PROJECT_ID_DEV" "dev"
if [ "$CREATE_BUCKETS" = "true" ]; then
    create_state_buckets "$PROJECT_ID_DEV" "dev"
fi

echo -e "${BLUE}Setting up Test Environment...${NC}"
setup_service_account "$PROJECT_ID_TEST" "test"
enable_apis "$PROJECT_ID_TEST" "test"
if [ "$CREATE_BUCKETS" = "true" ]; then
    create_state_buckets "$PROJECT_ID_TEST" "test"
fi

echo -e "${BLUE}Setting up Production Environment...${NC}"
setup_service_account "$PROJECT_ID_PROD" "prod"
enable_apis "$PROJECT_ID_PROD" "prod"
if [ "$CREATE_BUCKETS" = "true" ]; then
    create_state_buckets "$PROJECT_ID_PROD" "prod"
fi

# Create backend configurations if buckets were created
if [ "$CREATE_BUCKETS" = "true" ]; then
    create_backend_configs
fi

# Display secrets configuration
display_secrets_config

echo -e "${GREEN}🎉 GitHub Actions CI/CD Setup Complete!${NC}"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo "1. Configure GitHub repository secrets (see above)"
echo "2. Set up GitHub Environment protections (optional):"
echo "   - Go to Settings > Environments"
echo "   - Create environments: development, test, production"
echo "   - Configure protection rules and reviewers"
echo "3. Commit and push the .github/workflows files"
echo "4. Create a Pull Request to test the CI pipeline"
echo "5. Configure branch protection rules"
echo ""
echo -e "${YELLOW}⚠️  Security Notes:${NC}"
echo "- Store the generated JSON key files securely"
echo "- Consider rotating service account keys regularly"
echo "- Review and adjust IAM roles as needed"
echo "- Enable audit logging for production environments"
echo ""
echo -e "${YELLOW}⚠️  Environment Notes:${NC}"
echo "- Environment references in workflows are commented out"
echo "- Uncomment them after creating GitHub Environments"
echo "- This prevents workflow validation errors"