# Troubleshooting Guide - GitHub Actions CI/CD

Esta guía resuelve los problemas más comunes al implementar GitHub Actions con GCP.

## 🚨 Problemas Comunes y Soluciones

### 1. Error: Service Account Does Not Exist

**Error:**
```
ERROR: (gcloud.projects.add-iam-policy-binding) INVALID_ARGUMENT: Service account github-actions-sa@project-id.iam.gserviceaccount.com does not exist.
```

**Causa:** El script está intentando asignar roles antes de que el Service Account se haya creado completamente.

**Solución:**
```bash
# 1. Verificar que el Service Account existe
gcloud iam service-accounts describe github-actions-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com

# 2. Si no existe, crearlo manualmente
gcloud iam service-accounts create github-actions-sa \
  --display-name="GitHub Actions Service Account" \
  --project=YOUR_PROJECT_ID

# 3. Esperar y verificar
sleep 10
gcloud iam service-accounts describe github-actions-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com

# 4. Ejecutar el script nuevamente
./scripts/setup-github-actions.sh -d DEV_PROJECT -t TEST_PROJECT -p PROD_PROJECT
```

### 2. Error: Policy Modification Failed

**Error:**
```
ERROR: Policy modification failed. For a binding with condition, run "gcloud alpha iam policies lint-condition" to identify issues in condition.
```

**Causa:** Políticas IAM conflictivas o condiciones malformadas.

**Solución:**
```bash
# 1. Limpiar políticas existentes
gcloud projects get-iam-policy YOUR_PROJECT_ID --format=json > current-policy.json

# 2. Revisar políticas manualmente
gcloud alpha iam policies lint-condition --policy-file=current-policy.json

# 3. Asignar roles uno por uno
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

**Causa:** Los GitHub Environments deben crearse antes de usarlos en workflows.

**Solución:**
1. Ir a GitHub Repository → Settings → Environments
2. Crear environments:
   - `development`
   - `test` 
   - `production`
3. Descomentar las líneas `environment:` en los workflows
4. Opcional: Configurar protection rules and reviewers

### 4. Error: Authentication Failed in Workflow

**Error:**
```
Error: google-github-actions/auth failed with: failed to retrieve project ID
```

**Soluciones:**

#### A. Verificar Secret Configuration
```bash
# Verificar que el JSON es válido
echo "YOUR_SECRET_VALUE" | base64 -d | jq .
```

#### B. Verificar Permisos del Service Account
```bash
# Listar roles asignados
gcloud projects get-iam-policy YOUR_PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:github-actions-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com"
```

#### C. Regenerar Claves si es necesario
```bash
# Crear nueva clave
gcloud iam service-accounts keys create new-key.json \
  --iam-account=github-actions-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com

# Convertir a base64 para GitHub Secret
cat new-key.json | base64 -w 0
```

### 5. Error: APIs Not Enabled

**Error:**
```
API [compute.googleapis.com] not enabled on project
```

**Solución:**
```bash
# Habilitar todas las APIs necesarias
./scripts/enable_apis.sh YOUR_PROJECT_ID

# O manualmente:
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

**Soluciones:**

#### A. Verificar Bucket Existe
```bash
gsutil ls gs://YOUR_PROJECT_ID-terraform-state-dev
```

#### B. Crear Bucket si no existe
```bash
gsutil mb gs://YOUR_PROJECT_ID-terraform-state-dev
gsutil versioning set on gs://YOUR_PROJECT_ID-terraform-state-dev
```

#### C. Verificar Permisos
```bash
# El Service Account necesita roles/storage.admin
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:github-actions-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/storage.admin"
```

### 7. Error: Billing Account Issues

**Error:**
```
The billing account for the owning project is disabled
```

**Solución:**
```bash
# 1. Verificar billing accounts disponibles
gcloud billing accounts list

# 2. Vincular billing account al proyecto
gcloud billing projects link YOUR_PROJECT_ID \
  --billing-account=BILLING_ACCOUNT_ID

# 3. Verificar que está vinculado
gcloud billing projects describe YOUR_PROJECT_ID
```

### 8. Error: Terraform Plan Fails

**Error:**
```
Error: Error when reading or editing Project Service
```

**Diagnóstico y Solución:**
```bash
# 1. Verificar proyecto actual
gcloud config get-value project

# 2. Verificar APIs habilitadas
gcloud services list --enabled --project=YOUR_PROJECT_ID

# 3. Verificar permisos
gcloud projects get-iam-policy YOUR_PROJECT_ID

# 4. Probar terraform localmente
cd environments/dev
terraform init
terraform plan -var="project_id=YOUR_PROJECT_ID"
```

## 🔧 Comandos de Diagnóstico

### Verificar Estado del Setup

```bash
#!/bin/bash

PROJECT_ID="your-project-id"
SA_EMAIL="github-actions-sa@${PROJECT_ID}.iam.gserviceaccount.com"

echo "=== Diagnóstico del Setup ==="
echo "Proyecto: $PROJECT_ID"
echo "Service Account: $SA_EMAIL"
echo ""

# 1. Verificar proyecto
echo "1. Verificando proyecto..."
if gcloud projects describe "$PROJECT_ID" >/dev/null 2>&1; then
    echo "✅ Proyecto existe y es accesible"
else
    echo "❌ Proyecto no existe o no es accesible"
fi

# 2. Verificar Service Account
echo "2. Verificando Service Account..."
if gcloud iam service-accounts describe "$SA_EMAIL" >/dev/null 2>&1; then
    echo "✅ Service Account existe"
    
    # Verificar claves
    echo "   Claves disponibles:"
    gcloud iam service-accounts keys list --iam-account="$SA_EMAIL"
else
    echo "❌ Service Account no existe"
fi

# 3. Verificar APIs
echo "3. Verificando APIs habilitadas..."
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

# 4. Verificar billing
echo "4. Verificando billing..."
if gcloud billing projects describe "$PROJECT_ID" --format="value(billingEnabled)" | grep -q "True"; then
    echo "✅ Billing habilitado"
else
    echo "❌ Billing no habilitado"
fi

# 5. Verificar buckets de Terraform
echo "5. Verificando buckets de Terraform..."
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

### Script de Limpieza (si necesitas empezar de nuevo)

```bash
#!/bin/bash

PROJECT_ID="your-project-id"
SA_NAME="github-actions-sa"

echo "⚠️  ADVERTENCIA: Este script eliminará recursos de GCP"
read -p "¿Continuar? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

# 1. Eliminar claves del Service Account
echo "Eliminando claves del Service Account..."
gcloud iam service-accounts keys list \
    --iam-account="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
    --format="value(name)" | while read key; do
    if [[ "$key" != *"system-managed"* ]]; then
        gcloud iam service-accounts keys delete "$key" \
            --iam-account="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
            --quiet
    fi
done

# 2. Eliminar Service Account
echo "Eliminando Service Account..."
gcloud iam service-accounts delete \
    "${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
    --quiet

# 3. Eliminar archivos locales
echo "Eliminando archivos locales..."
rm -f github-actions-*.json
rm -f environments/*/backend.tf

echo "✅ Limpieza completada"
```

## 📞 Obtener Ayuda

### Logs Útiles

```bash
# Ver logs de Cloud Functions
gcloud functions logs read hello-world-dev --region=us-central1

# Ver logs de GitHub Actions
# (En la interfaz web de GitHub: Actions > Workflow > Job > Step)

# Ver estado de APIs
gcloud services list --enabled --project=YOUR_PROJECT_ID

# Ver políticas IAM
gcloud projects get-iam-policy YOUR_PROJECT_ID
```

### Contacto y Recursos

- **GitHub Actions Docs**: https://docs.github.com/en/actions
- **GCP IAM Troubleshooting**: https://cloud.google.com/iam/docs/troubleshooting
- **Terraform GCP Provider**: https://registry.terraform.io/providers/hashicorp/google/latest/docs

### Información para Reportar Issues

Cuando reportes problemas, incluye:

1. **Comando exacto ejecutado**
2. **Error completo (incluyendo stack trace)**
3. **IDs de proyecto utilizados**
4. **Versión de gcloud**: `gcloud version`
5. **Sistema operativo**
6. **Logs relevantes**

---

*💡 Tip: Siempre prueba los comandos localmente antes de depender de los workflows de GitHub Actions.* 