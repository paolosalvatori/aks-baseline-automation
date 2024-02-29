#!/bin/bash

# Getting started
# https://argoproj.github.io/argo-cd/getting_started/
# Also see:
# https://www.weave.works/blog/what-is-gitops-really

# Variables
server="miaargocd.babosbird.com"
username="admin"
externalCluster="MiaAks"
secretName="ArgoCdAdminPassword"
keyVaultName="BaboKeyVault"
gitHubRepo="https://github.com/paolosalvatori/aks-baseline-automation.git"
appName="flask"
appNamespace="flask"
appPath="workloads/flask"

# Read current password. You can use the following command to read the default password:
# password=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo)
password=$(
  az keyvault secret show \
    --name $secretName \
    --vault-name $keyVaultName \
    --query value \
    --output tsv
)

# Login
argocd login "miaargocd.babosbird.com" \
  --username $username \
  --password $password \
  --grpc-web \
  --skip-test-tls \
  --insecure

# Create app via CLI
# For more information, see https://argo-cd.readthedocs.io/en/stable/user-guide/commands/argocd_app_create/
# check if namespace exists in the cluster
result=$(kubectl get namespace -o jsonpath="{.items[?(@.metadata.name=='$appNamespace')].metadata.name}")

if [[ -n $result ]]; then
  echo "$appNamespace namespace already exists in the cluster"
else
  echo "$appNamespace namespace does not exist in the cluster"
  echo "creating $appNamespace namespace in the cluster..."
  kubectl create namespace $appNamespace
fi

argocd app create $appName \
  --repo $gitHubRepo \
  --path $appPath \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace $appNamespace \
  --grpc-web

# View app status
argocd app get $appName --grpc-web

# The application status is initially in OutOfSync state since the application has yet to be deployed,
# and no Kubernetes resources have been created. To sync (deploy) the application, run the sync command.
# This command retrieves the manifests from the repository and performs a kubectl apply of the manifests.
# The guestbook app is now running and you can now view its resource components, logs, events, and assessed health status.
argocd app sync $appName --grpc-web
