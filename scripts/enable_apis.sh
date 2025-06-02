#!/bin/bash

# Enable GCP APIs for Hello World Infrastructure
# Usage: ./enable_apis.sh PROJECT_ID

set -e

PROJECT_ID=${1:-$GOOGLE_PROJECT}

if [ -z "$PROJECT_ID" ]; then
    echo "Error: PROJECT_ID is required"
    echo "Usage: $0 PROJECT_ID"
    echo "Or set GOOGLE_PROJECT environment variable"
    exit 1
fi

echo "Enabling APIs for project: $PROJECT_ID"

# Required APIs
APIS=(
    "compute.googleapis.com"
    "cloudfunctions.googleapis.com"
    "storage.googleapis.com"
    "logging.googleapis.com"
    "cloudbuild.googleapis.com"
    "iam.googleapis.com"
    "serviceusage.googleapis.com"
)

# Set the project
gcloud config set project "$PROJECT_ID"

# Check if billing is enabled
echo "Checking billing status..."
BILLING_ACCOUNT=$(gcloud billing projects describe "$PROJECT_ID" --format="value(billingAccountName)" 2>/dev/null || echo "")

if [ -z "$BILLING_ACCOUNT" ]; then
    echo "Warning: No billing account found for project $PROJECT_ID"
    echo "You may need to link a billing account to this project"
fi

# Enable each API
for api in "${APIS[@]}"; do
    echo "Enabling $api..."
    gcloud services enable "$api" --project="$PROJECT_ID"
    if [ $? -eq 0 ]; then
        echo "✓ Successfully enabled $api"
    else
        echo "✗ Failed to enable $api"
    fi
done

echo "Waiting for APIs to propagate..."
sleep 30

echo "✓ All APIs enabled successfully!"
echo "You can now run terraform apply" 