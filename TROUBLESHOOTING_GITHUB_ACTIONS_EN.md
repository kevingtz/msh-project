# Troubleshooting Guide - GitHub Actions CI/CD

This guide resolves the most common issues when implementing GitHub Actions with GCP.

## 🚨 Common Issues and Solutions

### 1. Error: Service Account Does Not Exist

**Error:**
```
ERROR: (gcloud.projects.add-iam-policy-binding) INVALID_ARGUMENT: Service account github-actions-sa@project-id.iam.gserviceaccount.com does not exist.
```

**Cause:** The script is trying to assign roles before the Service Account has been completely created.

**Solution:**
```bash
# 1. Verify that the Service Account exists
gcloud iam service-accounts describe github-actions-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com

# 2. If it doesn't exist, create it manually
gcloud iam service-accounts create github-actions-sa \
  --display-name="GitHub Actions Service Account" \
  --project=YOUR_PROJECT_ID

# 3. Wait and verify
sleep 10
gcloud iam service-accounts describe github-actions-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com

# 4. Run the script again
./scripts/setup-github-actions.sh -d DEV_PROJECT -t TEST_PROJECT -p PROD_PROJECT
```

### 2. Error: Policy Modification Failed

**Error:**
```
ERROR: Policy modification failed. For a binding with condition, run "gcloud alpha iam policies lint-condition" to identify issues in condition.
```

**Cause:** Conflicting IAM policies or malformed conditions.

**Solution:**
```bash
# 1. Clean existing policies
gcloud projects get-iam-policy YOUR_PROJECT_ID --format=json > current-policy.json

# 2. Review policies manually
gcloud alpha iam policies lint-condition --policy-file=current-policy.json

# 3. Assign roles one by one
ROLES=(
  "roles/compute.admin"
  "roles/cloudfunctions.admin"
  "roles/storage.admin"
  "roles/iam.serviceAccountUser"
)

for role in "${ROLES[@]}"; do
  echo "Assigning $role"
  gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
    --member="serviceAccount:github-actions-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
    --role="$role"
done
```

### 3. Error: GitHub Environment Not Valid

**Error:**
```
Value 'development' is not valid
```

**Cause:** GitHub Environments must be created before using them in workflows.

**Solution:**
1. Go to GitHub Repository → Settings → Environments
2. Create environments:
   - `development`
   - `test` 
   - `production`
3. Uncomment the `environment:` lines in the workflows
4. Optional: Configure protection rules and reviewers

### 4. Error: Authentication Failed in Workflow

**Error:**
```
Error: google-github-actions/auth failed with: failed to retrieve project ID
```

**Solutions:**

#### A. Verify Secret Configuration
```bash
# Verify that the JSON is valid
echo "YOUR_SECRET_VALUE" | base64 -d | jq .
```

#### B. Verify Service Account Permissions
```bash
# List assigned roles
gcloud projects get-iam-policy YOUR_PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:github-actions-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com"
```

#### C. Regenerate Keys if Necessary
```bash
# Create new key
gcloud iam service-accounts keys create new-key.json \
  --iam-account=github-actions-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com

# Convert to base64 for GitHub Secret
cat new-key.json | base64 -w 0
```

### 5. Error: APIs Not Enabled

**Error:**
```
API [compute.googleapis.com] not enabled on project
```

**Solution:**
```bash
# Enable all necessary APIs
./scripts/enable_apis.sh YOUR_PROJECT_ID

# Or manually:
gcloud services enable compute.googleapis.com \
  cloudfunctions.googleapis.com \
  storage.googleapis.com \
  logging.googleapis.com \
  cloudbuild.googleapis.com \
  iam.googleapis.com \
  --project=YOUR_PROJECT_ID
```

### 6. Error: Terraform Backend Issues

**Error:**
```
Error: Failed to get existing workspaces: querying Cloud Storage failed
```

**Solutions:**

#### A. Verify Bucket Exists
```bash
gsutil ls gs://YOUR_PROJECT_ID-terraform-state-dev
```

#### B. Create Bucket if it Doesn't Exist
```bash
gsutil mb gs://YOUR_PROJECT_ID-terraform-state-dev
gsutil versioning set on gs://YOUR_PROJECT_ID-terraform-state-dev
```

#### C. Verify Permissions
```bash
# The Service Account needs roles/storage.admin
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:github-actions-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/storage.admin"
```

### 7. Error: Billing Account Issues

**Error:**
```
The billing account for the owning project is disabled
```

**Solution:**
```bash
# 1. Verify available billing accounts
gcloud billing accounts list

# 2. Link billing account to project
gcloud billing projects link YOUR_PROJECT_ID \
  --billing-account=BILLING_ACCOUNT_ID

# 3. Verify it's linked
gcloud billing projects describe YOUR_PROJECT_ID
```

### 8. Error: Terraform Plan Fails

**Error:**
```
Error: Error when reading or editing Project Service
```

**Diagnosis and Solution:**
```bash
# 1. Verify current project
gcloud config get-value project

# 2. Verify enabled APIs
gcloud services list --enabled --project=YOUR_PROJECT_ID

# 3. Verify permissions
gcloud projects get-iam-policy YOUR_PROJECT_ID

# 4. Test terraform locally
cd environments/dev
terraform init
terraform plan -var="project_id=YOUR_PROJECT_ID"
```

## 🔧 Diagnostic Commands

### Verify Setup Status

```bash
#!/bin/bash

PROJECT_ID="your-project-id"
SA_EMAIL="github-actions-sa@${PROJECT_ID}.iam.gserviceaccount.com"

echo "=== Setup Diagnosis ==="
echo "Project: $PROJECT_ID"
echo "Service Account: $SA_EMAIL"
echo ""

# 1. Verify project
echo "1. Verifying project..."
if gcloud projects describe "$PROJECT_ID" >/dev/null 2>&1; then
    echo "✅ Project exists and is accessible"
else
    echo "❌ Project does not exist or is not accessible"
fi

# 2. Verify Service Account
echo "2. Verifying Service Account..."
if gcloud iam service-accounts describe "$SA_EMAIL" >/dev/null 2>&1; then
    echo "✅ Service Account exists"
    
    # Verify keys
    echo "   Available keys:"
    gcloud iam service-accounts keys list --iam-account="$SA_EMAIL"
else
    echo "❌ Service Account does not exist"
fi

# 3. Verify APIs
echo "3. Verifying enabled APIs..."
APIS=(
    "compute.googleapis.com"
    "cloudfunctions.googleapis.com"
    "storage.googleapis.com"
    "iam.googleapis.com"
)

for api in "${APIS[@]}"; do
    if gcloud services list --enabled --filter="name:$api" --format="value(name)" | grep -q "$api"; then
        echo "✅ $api"
    else
        echo "❌ $api"
    fi
done

# 4. Verify billing
echo "4. Verifying billing..."
if gcloud billing projects describe "$PROJECT_ID" --format="value(billingEnabled)" | grep -q "True"; then
    echo "✅ Billing enabled"
else
    echo "❌ Billing not enabled"
fi

# 5. Verify Terraform buckets
echo "5. Verifying Terraform buckets..."
BUCKETS=(
    "${PROJECT_ID}-terraform-state-dev"
    "${PROJECT_ID}-terraform-state-test"
    "${PROJECT_ID}-terraform-state-prd"
)

for bucket in "${BUCKETS[@]}"; do
    if gsutil ls "gs://$bucket" >/dev/null 2>&1; then
        echo "✅ gs://$bucket"
    else
        echo "❌ gs://$bucket"
    fi
done
```

### Cleanup Script (if you need to start over)

```bash
#!/bin/bash

PROJECT_ID="your-project-id"
SA_NAME="github-actions-sa"

echo "⚠️  WARNING: This script will delete GCP resources"
read -p "Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

# 1. Delete Service Account keys
echo "Deleting Service Account keys..."
gcloud iam service-accounts keys list \
    --iam-account="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
    --format="value(name)" | while read key; do
    if [[ "$key" != *"system-managed"* ]]; then
        gcloud iam service-accounts keys delete "$key" \
            --iam-account="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
            --quiet
    fi
done

# 2. Delete Service Account
echo "Deleting Service Account..."
gcloud iam service-accounts delete \
    "${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
    --quiet

# 3. Delete local files
echo "Deleting local files..."
rm -f github-actions-*.json
rm -f environments/*/backend.tf

echo "✅ Cleanup completed"
```

## 📞 Getting Help

### Useful Logs

```bash
# View Cloud Functions logs
gcloud functions logs read hello-world-dev --region=us-central1

# View GitHub Actions logs
# (In GitHub web interface: Actions > Workflow > Job > Step)

# View API status
gcloud services list --enabled --project=YOUR_PROJECT_ID

# View IAM policies
gcloud projects get-iam-policy YOUR_PROJECT_ID
```

### Contact and Resources

- **GitHub Actions Docs**: https://docs.github.com/en/actions
- **GCP IAM Troubleshooting**: https://cloud.google.com/iam/docs/troubleshooting
- **Terraform GCP Provider**: https://registry.terraform.io/providers/hashicorp/google/latest/docs

### Information to Include When Reporting Issues

When reporting issues, include:

1. **Exact command executed**
2. **Complete error (including stack trace)**
3. **Project IDs used**
4. **gcloud version**: `gcloud version`
5. **Operating system**
6. **Relevant logs**

---

*💡 Tip: Always test commands locally before relying on GitHub Actions workflows.* 