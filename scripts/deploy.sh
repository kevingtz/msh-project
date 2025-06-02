#!/bin/bash

# GCP Hello World Infrastructure Deployment Script
# This script automates the deployment process for different environments

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
ENVIRONMENT="dev"
PROJECT_ID=""
REGION="us-central1"
ACTION="apply"

# Function to print usage
usage() {
    echo "Usage: $0 -p PROJECT_ID [-e ENVIRONMENT] [-r REGION] [-a ACTION]"
    echo ""
    echo "Options:"
    echo "  -p PROJECT_ID   GCP Project ID (required)"
    echo "  -e ENVIRONMENT  Environment (dev, test, prd) [default: dev]"
    echo "  -r REGION       GCP Region [default: us-central1]"
    echo "  -a ACTION       Terraform action (plan, apply, destroy) [default: apply]"
    echo "  -h              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -p my-gcp-project -e dev"
    echo "  $0 -p my-gcp-project -e prod -a plan"
    echo "  $0 -p my-gcp-project -e test -a destroy"
}

# Parse command line arguments
while getopts "p:e:r:a:h" opt; do
    case $opt in
        p)
            PROJECT_ID="$OPTARG"
            ;;
        e)
            ENVIRONMENT="$OPTARG"
            ;;
        r)
            REGION="$OPTARG"
            ;;
        a)
            ACTION="$OPTARG"
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
if [ -z "$PROJECT_ID" ]; then
    echo -e "${RED}Error: PROJECT_ID is required${NC}"
    usage
    exit 1
fi

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|test|prd)$ ]]; then
    echo -e "${RED}Error: Environment must be dev, test, or prd${NC}"
    exit 1
fi

# Validate action
if [[ ! "$ACTION" =~ ^(plan|apply|destroy)$ ]]; then
    echo -e "${RED}Error: Action must be plan, apply, or destroy${NC}"
    exit 1
fi

echo -e "${GREEN}Starting deployment with the following configuration:${NC}"
echo "  Project ID: $PROJECT_ID"
echo "  Environment: $ENVIRONMENT"
echo "  Region: $REGION"
echo "  Action: $ACTION"
echo ""

# Change to environment directory
ENV_DIR="environments/$ENVIRONMENT"
if [ ! -d "$ENV_DIR" ]; then
    echo -e "${RED}Error: Environment directory $ENV_DIR does not exist${NC}"
    exit 1
fi

cd "$ENV_DIR"

# Check if gcloud is authenticated
echo -e "${YELLOW}Checking GCP authentication...${NC}"
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
    echo -e "${RED}Error: Not authenticated with GCP. Please run 'gcloud auth application-default login'${NC}"
    exit 1
fi

# Set the project
echo -e "${YELLOW}Setting GCP project...${NC}"
gcloud config set project "$PROJECT_ID"

# Enable required APIs
echo -e "${YELLOW}Enabling required GCP APIs...${NC}"
gcloud services enable cloudfunctions.googleapis.com
gcloud services enable compute.googleapis.com
gcloud services enable storage.googleapis.com
gcloud services enable logging.googleapis.com

# Create tfvars file if it doesn't exist
if [ ! -f "terraform.tfvars" ]; then
    echo -e "${YELLOW}Creating terraform.tfvars file...${NC}"
    cat > terraform.tfvars <<EOF
project_id = "$PROJECT_ID"
region     = "$REGION"
EOF
fi

# Initialize Terraform
echo -e "${YELLOW}Initializing Terraform...${NC}"
terraform init

# Run Terraform action
case $ACTION in
    plan)
        echo -e "${YELLOW}Running Terraform plan...${NC}"
        terraform plan -var="project_id=$PROJECT_ID" -var="region=$REGION"
        ;;
    apply)
        echo -e "${YELLOW}Running Terraform apply...${NC}"
        terraform apply -var="project_id=$PROJECT_ID" -var="region=$REGION" -auto-approve
        
        echo -e "${GREEN}Deployment completed successfully!${NC}"
        echo ""
        echo "You can access your infrastructure at:"
        terraform output load_balancer_url
        terraform output function_url
        ;;
    destroy)
        echo -e "${YELLOW}Running Terraform destroy...${NC}"
        terraform destroy -var="project_id=$PROJECT_ID" -var="region=$REGION" -auto-approve
        
        echo -e "${GREEN}Infrastructure destroyed successfully!${NC}"
        ;;
esac

echo -e "${GREEN}Script completed successfully!${NC}" 