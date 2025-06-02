# GCP Hello World Infrastructure

A production-ready "Hello World" infrastructure on Google Cloud Platform using Terraform, implementing Clean Architecture principles.

## 🏗️ Architecture

This project implements a serverless "Hello World" application with enterprise-grade security and scalability:

- **Cloud Function** (Python 3.10) - Core application logic
- **Global HTTP(S) Load Balancer** - Traffic distribution and SSL termination
- **Cloud Armor** - WAF protection with OWASP rules and geo-blocking
- **Serverless NEG** - Connects function to load balancer
- **Cloud Storage** - Function source code storage
- **Cloud Logging** - Centralized logging and monitoring

## 📋 Prerequisites

### Required Tools
- Terraform >= 1.0
- Go >= 1.19 (for Terratest)
- Google Cloud SDK
- Active GCP Project with billing enabled

### GCP Requirements
- **Billing Account**: Must be enabled and linked to your GCP project
- **Required APIs**: The following APIs will be automatically enabled:
  - Compute Engine API
  - Cloud Functions API
  - Cloud Storage API
  - Cloud Logging API
  - Cloud Build API
  - IAM API

### Authentication
```bash
# Authenticate with GCP
gcloud auth login
gcloud auth application-default login

# Set your project
gcloud config set project YOUR_PROJECT_ID
```

## 🚀 Quick Start

### 1. Enable APIs (Optional - done automatically)
```bash
# Navigate to terratest directory for API enablement
cd terratest
terraform init
terraform apply -var="project_id=YOUR_PROJECT_ID"
cd ..
```

### 2. Deploy Infrastructure
```bash
# Clone the repository
git clone <repository-url>
cd gcp-hello-world

# Navigate to environment
cd environments/dev

# Copy and customize variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your project ID

# Deploy
terraform init
terraform plan -var="project_id=YOUR_PROJECT_ID"
terraform apply -var="project_id=YOUR_PROJECT_ID"
```

### 3. Test the Application
```bash
# Get the URLs from terraform output
terraform output function_url
terraform output load_balancer_url

# Test the function directly
curl $(terraform output -raw function_url)

# Test through load balancer (may take 10-15 minutes to be fully ready)
curl $(terraform output -raw load_balancer_url)
```

## 🧪 Testing

### Automated Testing with Terratest
```bash
cd terratest

# Install dependencies
go mod download

# Set your project ID
export GOOGLE_PROJECT=YOUR_PROJECT_ID

# Run tests
go test -v -timeout 30m
```

### Manual Testing
```bash
# Test API enablement
cd terratest
terraform init
terraform apply -var="project_id=YOUR_PROJECT_ID"

# Deploy and test infrastructure
cd ../environments/dev
terraform init
terraform apply -var="project_id=YOUR_PROJECT_ID"
```

## 🗂️ Project Structure

```
gcp-hello-world/
├── main.tf                    # Root module orchestration
├── variables.tf               # Root variables (auto-generated)
├── outputs.tf                 # Root outputs (auto-generated)
├── modules/
│   ├── apis/                  # API enablement module
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── cloud_function/        # Cloud Function module
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── main.py           # Python function code
│   │   └── requirements.txt
│   ├── load_balancer/        # Load balancer module
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── cloud_armor/          # Security module
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
├── environments/
│   ├── dev/                  # Development environment
│   ├── test/                 # Test environment
│   └── prd/                  # Production environment
├── terratest/                # Automated testing
│   ├── hello_world_test.go
│   ├── enable_apis.tf       # API enablement for testing
│   └── go.mod
├── scripts/
│   └── deploy.sh            # Deployment automation
└── docs/
    └── DEPLOYMENT_GUIDE.md
```

## ⚠️ Troubleshooting

### Common Issues

1. **Billing Account Disabled**
   ```
   Error: The billing account for the owning project is disabled
   ```
   **Solution**: Ensure your GCP project has an active billing account linked.

2. **APIs Not Enabled**
   ```
   Error: Compute Engine API has not been used in project
   ```
   **Solution**: The infrastructure will automatically enable required APIs. If issues persist, manually enable them:
   ```bash
   gcloud services enable compute.googleapis.com
   gcloud services enable cloudfunctions.googleapis.com
   ```

3. **Load Balancer Takes Time**
   - Global load balancers can take 10-15 minutes to become fully operational
   - SSL certificates may take additional time to provision
   - Monitor in GCP Console: Network Services > Load Balancing

4. **Permission Errors**
   ```bash
   # Ensure you have the required roles
   gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
     --member="user:YOUR_EMAIL" \
     --role="roles/editor"
   ```

### Testing with Billing Issues
If you encounter billing issues during testing, the tests will automatically skip with appropriate logging:

```bash
# Tests will show:
=== SKIP: TestHelloWorld
    Skipping test due to billing account issue: ...
```

## 🏛️ Clean Architecture Implementation

### Business Logic Layer
- **Domain**: Pure business logic in `main.py`
- **Use Cases**: Request handling and response formatting
- **Entities**: Data structures and business rules

### Framework Layer
- **Infrastructure**: Terraform modules for cloud resources
- **External Interfaces**: HTTP endpoints and cloud services
- **Configuration**: Environment-specific settings

### Benefits
- **Framework Independence**: Business logic isolated from cloud specifics
- **Testability**: Easy unit and integration testing
- **Maintainability**: Clear separation of concerns
- **Scalability**: Modular design for easy extension

## 🔒 Security Features

- **Cloud Armor WAF**: OWASP protection against common attacks
- **Geo-blocking**: Configurable regional access controls
- **HTTPS Enforcement**: Managed SSL certificates
- **IAM**: Principle of least privilege access
- **VPC**: Network isolation and security

## 🌍 Multi-Environment Support

Each environment (`dev`, `test`, `prd`) has its own:
- Variable configurations
- State management
- Resource naming conventions
- Security policies

## 📊 Monitoring & Logging

- **Cloud Logging**: Centralized log aggregation
- **Function Logs**: Structured application logging
- **Load Balancer Logs**: Traffic analysis and debugging
- **Security Logs**: Cloud Armor event tracking

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add/update tests
5. Submit a pull request

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details. 