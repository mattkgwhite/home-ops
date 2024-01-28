#!/bin/bash

# Check if dry-run flag is set
if [ "$1" == "--dry-run" ]; then
    echo "Dry-run flag set"
    DRY_RUN="server"
else
    DRY_RUN="none"
fi

# Set our variables
HELM_REPO_NAME="external-secrets"
HELM_REPO_SOURCE="https://charts.external-secrets.io"
HELM_APP_NAME="external-secrets"
HELM_APP_VERSION="0.9.11"
HELM_APP_NAMESPACE="external-secrets"

# Add the Helm repository
helm repo add ${HELM_REPO_NAME} ${HELM_REPO_SOURCE}
# Update your local Helm chart repository cache
helm repo update
# Template out and install the Helm chart via pipe to `kubectl apply`
helm template ${HELM_APP_NAME} ${HELM_REPO_NAME}/${HELM_APP_NAME} \
--version ${HELM_APP_VERSION} \
--values values.yaml \
-n ${HELM_APP_NAMESPACE} | \
kubectl apply -f - --dry-run=${DRY_RUN}
