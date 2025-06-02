# Deployment Guide

This guide provides step-by-step instructions for deploying the GCP Hello World infrastructure.

## Prerequisites

### 1. GCP Project Setup
```bash
# Create a new project (optional)
gcloud projects create your-project-id
gcloud config set project your-project-id

# Ensure billing is enabled for your project
# This is REQUIRED for Cloud Functions and Load Balancers
gcloud billing projects link your-project-id --billing-account=BILLING_ACCOUNT_ID
```

### 2. Enable Required APIs

#### Option A: Automatic (via Terraform)
The infrastructure includes an APIs module that automatically enables required services. However, this requires that the `serviceusage.googleapis.com` API is already enabled.

#### Option B: Manual (Recommended)
```bash
# Use the provided script
./scripts/enable_apis.sh your-project-id

# Or manually enable each API
gcloud services enable compute.googleapis.com
gcloud services enable cloudfunctions.googleapis.com
gcloud services enable storage.googleapis.com
gcloud services enable logging.googleapis.com
gcloud services enable cloudbuild.googleapis.com
gcloud services enable iam.googleapis.com
```

#### Option C: Via Terraform (Separate step)
```bash
# Navigate to terratest directory and enable APIs first
cd terratest
terraform init
terraform apply -var="project_id=your-project-id"
cd ../environments/dev
```

### 3. Authentication
```bash
# Authenticate with GCP
gcloud auth login
gcloud auth application-default login

# Set your project
gcloud config set project your-project-id
```

## Deployment Steps

### Development Environment

1. **Navigate to dev environment**
   ```bash
   cd environments/dev
   ```

2. **Create terraform.tfvars**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```
   
   Edit `terraform.tfvars`:
   ```hcl
   project_id = "your-project-id"
   region     = "us-central1"
   domains    = ["yourdomain.com"]  # Optional: for custom SSL
   ```

3. **Deploy infrastructure**
   ```bash
   terraform init
   terraform plan -var="project_id=your-project-id"
   terraform apply -var="project_id=your-project-id"
   ```

4. **Get deployment outputs**
   ```bash
   terraform output function_url
   terraform output load_balancer_url
   ```

### Test Environment

```bash
cd environments/test
terraform init
terraform apply -var="project_id=your-test-project"
```

### Production Environment

```bash
cd environments/prd
terraform init
terraform apply -var="project_id=your-prod-project"
```

## Testing the Deployment

### 1. Test Cloud Function Directly
```bash
FUNCTION_URL=$(terraform output -raw function_url)
curl $FUNCTION_URL

# Expected response: "Hello, World! Environment: dev"
```

### 2. Test Load Balancer (Wait 10-15 minutes)
```bash
LB_URL=$(terraform output -raw load_balancer_url)
curl $LB_URL

# Load balancers take time to provision
# Check status in GCP Console: Network Services > Load Balancing
```

### 3. Run Automated Tests
```bash
cd terratest
export GOOGLE_PROJECT=your-project-id
go test -v -timeout 30m
```

## Troubleshooting

### Common Issues

#### 1. Billing Account Not Enabled
```
Error: The billing account for the owning project is disabled in state absent
```

**Solution:**
```bash
# List available billing accounts
gcloud billing accounts list

# Link billing account to project
gcloud billing projects link your-project-id \
  --billing-account=BILLING_ACCOUNT_ID
```

#### 2. APIs Not Enabled
```
Error: Compute Engine API has not been used in project before or it is disabled
```

**Solution:**
```bash
# Enable APIs using our script
./scripts/enable_apis.sh your-project-id

# Or manually
gcloud services enable compute.googleapis.com
```

#### 3. Insufficient Permissions
```
Error: The caller does not have permission
```

**Solution:**
```bash
# Ensure you have required roles
gcloud projects add-iam-policy-binding your-project-id \
  --member="user:your-email@domain.com" \
  --role="roles/editor"
```

#### 4. SSL Certificate Issues
SSL certificates can take 10-60 minutes to provision and may require:
- Domain ownership verification
- DNS pointing to load balancer IP
- Time for global propagation

#### 5. Load Balancer Health Check Failures
```bash
# Check backend service health
gcloud compute backend-services get-health hello-world-backend --global

# Check NEG endpoints
gcloud compute network-endpoint-groups list
```

### Debugging Steps

1. **Check Terraform State**
   ```bash
   terraform show
   terraform state list
   ```

2. **Validate Configuration**
   ```bash
   terraform validate
   terraform plan
   ```

3. **Check GCP Resources**
   ```bash
   # Functions
   gcloud functions list
   gcloud functions describe hello-world-dev --region=us-central1
   
   # Load Balancer
   gcloud compute forwarding-rules list
   gcloud compute backend-services list
   
   # Security Policy
   gcloud compute security-policies list
   ```

4. **View Logs**
   ```bash
   # Function logs
   gcloud functions logs read hello-world-dev
   
   # Load balancer logs (if enabled)
   gcloud logging read "resource.type=http_load_balancer"
   ```

### Performance Considerations

#### Cold Starts
- Cloud Functions may have 1-2 second cold start delays
- Consider keeping functions warm for production

#### Global Load Balancer
- Global LB provides lowest latency worldwide
- SSL termination at edge locations
- Backend services health checking

#### Security
- Cloud Armor provides WAF protection
- HTTPS enforced via managed SSL certificates
- IAM controls access to infrastructure

## Cleanup

### Remove Infrastructure
```bash
# From the environment directory
terraform destroy -var="project_id=your-project-id"

# Confirm destruction when prompted
```

### Remove APIs (Optional)
```bash
# APIs can be disabled but may affect other resources
gcloud services disable compute.googleapis.com --force
gcloud services disable cloudfunctions.googleapis.com --force
```

## Advanced Configuration

### Custom Domains
1. Update `domains` variable in terraform.tfvars
2. Point DNS A record to load balancer IP
3. Wait for SSL certificate provisioning

### Multi-Region Deployment
Deploy to multiple regions by:
1. Creating region-specific environment folders
2. Updating region variables
3. Managing state files separately

### CI/CD Integration
```bash
# Example GitHub Actions workflow
- name: Deploy to Dev
  run: |
    cd environments/dev
    terraform init
    terraform apply -auto-approve -var="project_id=${{ secrets.GCP_PROJECT }}"
```

This guide should help you successfully deploy and troubleshoot the GCP Hello World infrastructure. 