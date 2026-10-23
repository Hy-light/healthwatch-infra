#!/usr/bin/env bash
# =============================================================================
#  One-time setup for the HealthWatch Naija demo.
#  Run this in Azure Cloud Shell (Bash): https://shell.azure.com
#
#  It creates:
#    1. A storage account to hold Terraform state (the "memory" of Terraform)
#    2. An identity for GitHub Actions, trusted via OIDC (no passwords/secrets)
#    3. Permissions for that identity
#  and prints the 5 values you paste into GitHub (Settings > Secrets and
#  variables > Actions > Variables).
#
#  Usage:
#    GITHUB_REPO="your-github-username/healthwatch-infra" bash bootstrap-azure.sh
# =============================================================================
set -euo pipefail

: "${GITHUB_REPO:?Set GITHUB_REPO, e.g. GITHUB_REPO=puchime/healthwatch-infra}"
LOCATION="${LOCATION:-southafricanorth}"
STATE_RG="${STATE_RG:-rg-hwn-tfstate}"
APP_NAME="${APP_NAME:-sp-healthwatch-github}"

SUBSCRIPTION_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)
echo ">> Subscription: $(az account show --query name -o tsv) ($SUBSCRIPTION_ID)"

echo ">> Registering resource providers (safe to re-run)"
for p in Microsoft.Storage Microsoft.Network Microsoft.OperationalInsights Microsoft.Consumption; do
  az provider register --namespace "$p" --wait --output none
done

echo ">> 1/3 Terraform state storage"
az group create -n "$STATE_RG" -l "$LOCATION" --tags purpose=terraform-state application=healthwatch-naija -o none
EXISTING_SA=$(az storage account list -g "$STATE_RG" --query "[0].name" -o tsv)
if [ -n "$EXISTING_SA" ]; then
  STATE_SA="$EXISTING_SA"
  echo "   reusing $STATE_SA"
else
  STATE_SA="sthwntfstate$RANDOM"
  az storage account create -n "$STATE_SA" -g "$STATE_RG" -l "$LOCATION" \
    --sku Standard_LRS --min-tls-version TLS1_2 --allow-blob-public-access false -o none
fi
SA_ID=$(az storage account show -n "$STATE_SA" -g "$STATE_RG" --query id -o tsv)
az storage container create --name tfstate --account-name "$STATE_SA" --auth-mode login -o none 2>/dev/null \
  || az storage container create --name tfstate --account-name "$STATE_SA" -o none
az storage account blob-service-properties update --account-name "$STATE_SA" -g "$STATE_RG" \
  --enable-versioning true -o none

echo ">> 2/3 GitHub Actions identity (OIDC)"
APP_ID=$(az ad app list --display-name "$APP_NAME" --query "[0].appId" -o tsv)
if [ -z "$APP_ID" ]; then
  APP_ID=$(az ad app create --display-name "$APP_NAME" --query appId -o tsv)
fi
az ad sp show --id "$APP_ID" -o none 2>/dev/null || az ad sp create --id "$APP_ID" -o none
SP_OBJECT_ID=$(az ad sp show --id "$APP_ID" --query id -o tsv)

add_fic () {   # name, subject
  if [ -n "$(az ad app federated-credential list --id "$APP_ID" --query "[?name=='$1'].name" -o tsv)" ]; then
    echo "   federated credential '$1' exists"
  else
    az ad app federated-credential create --id "$APP_ID" --parameters "{
      \"name\": \"$1\",
      \"issuer\": \"https://token.actions.githubusercontent.com\",
      \"subject\": \"$2\",
      \"audiences\": [\"api://AzureADTokenExchange\"]
    }" -o none
    echo "   added federated credential '$1'"
  fi
}
# GitHub sends one of two "subject" formats when it logs in to Azure:
#   classic : repo:owner/repo:...
#   newer   : repo:owner@<owner-id>/repo@<repo-id>:...   (newer repos/accounts)
# We register BOTH, so it works whichever format your repo uses.
GH_OWNER="${GITHUB_REPO%%/*}"
GH_NAME="${GITHUB_REPO##*/}"
REPO_JSON=$(curl -fsSL "https://api.github.com/repos/${GH_OWNER}/${GH_NAME}" || true)
OWNER_NUM=$(echo "$REPO_JSON" | jq -r '.owner.id // empty' 2>/dev/null || true)
REPO_NUM=$(echo "$REPO_JSON" | jq -r '.id // empty' 2>/dev/null || true)

for SUBJ_REPO in "${GITHUB_REPO}" ${OWNER_NUM:+"${GH_OWNER}@${OWNER_NUM}/${GH_NAME}@${REPO_NUM}"}; do
  SUFFIX=""; [ "$SUBJ_REPO" != "$GITHUB_REPO" ] && SUFFIX="-ids"
  add_fic "gh-pull-request${SUFFIX}" "repo:${SUBJ_REPO}:pull_request"
  add_fic "gh-main${SUFFIX}"         "repo:${SUBJ_REPO}:ref:refs/heads/main"
  add_fic "gh-production${SUFFIX}"   "repo:${SUBJ_REPO}:environment:production"
done
[ -z "$OWNER_NUM" ] && echo "   (could not read repo IDs from GitHub; is the repo public and the name right? Only classic format registered.)"

echo ">> 3/3 Permissions"
assign_role () {   # role, scope
  if [ -n "$(az role assignment list --assignee "$SP_OBJECT_ID" --role "$1" --scope "$2" --query "[0].id" -o tsv)" ]; then
    echo "   role '$1' already assigned"
  else
    # No error hiding: if you are not Owner / User Access Administrator this stops here, clearly.
    az role assignment create --assignee-object-id "$SP_OBJECT_ID" --assignee-principal-type ServicePrincipal \
      --role "$1" --scope "$2" -o none
    echo "   assigned '$1'"
  fi
}
# Contributor on the subscription so Terraform can create resource groups.
# In a real company you would scope this tighter (e.g. a dedicated subscription).
assign_role "Contributor" "/subscriptions/$SUBSCRIPTION_ID"
# Read/write Terraform state with Entra ID (no storage keys).
assign_role "Storage Blob Data Contributor" "$SA_ID"

cat <<EOF

=============================================================================
 DONE. In GitHub: repo > Settings > Secrets and variables > Actions >
 "Variables" tab > New repository variable. Add these 5:

   AZURE_CLIENT_ID          = $APP_ID
   AZURE_TENANT_ID          = $TENANT_ID
   AZURE_SUBSCRIPTION_ID    = $SUBSCRIPTION_ID
   TFSTATE_RESOURCE_GROUP   = $STATE_RG
   TFSTATE_STORAGE_ACCOUNT  = $STATE_SA

 (They are IDs, not passwords. OIDC means there is no secret to leak.)
 Role assignments can take 1-2 minutes to take effect.
=============================================================================
EOF
