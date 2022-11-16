#!/bin/bash

# Getting started
# https://argoproj.github.io/argo-cd/getting_started/
# Also see:
# https://www.weave.works/blog/what-is-gitops-really

# variables
server="miaargocd.babosbird.com"
username="admin"
secretName="ArgoCdAdminPassword"
keyVaultName="BaboKeyVault"
appName="flask"
repoName="https://github.com/paolosalvatori/aks-baseline-automation.git"
path="workloads/flask"
syncPolicy="automated"
namespace="flask-cd"
destinationServer="https://kubernetes.default.svc"

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
# For more information, see https://argo-cd.readthedocs.io/en/stable/user-guide/commands/argocd_login/
argocd login $server \
  --username $username \
  --password $password \
  --grpc-web

# Create namespace
result=$(kubectl get namespace -o 'jsonpath={.items[?(@.metadata.name=="'$namespace'")].metadata.name'})

if [[ -n $result ]]; then
  echo "$namespace namespace already exists in the cluster"
else
  echo "$namespace namespace does not exist in the cluster"
  echo "creating $namespace namespace in the cluster..."
  kubectl create namespace $namespace
fi

# Create Argo CD application via CLI
# For more information, see https://argo-cd.readthedocs.io/en/stable/user-guide/commands/argocd_app_create/
argocd app get $appName &>/dev/null

if [[ $? == 0 ]]; then
  echo "[$appName] application already exists in the [$server] Argo CD "
else
  echo "[$appName] application does not exist in the [$server] Argo CD"
  echo "Creating [$appName] application in the [$server] Argo CD"
  argocd app create $appName \
    --repo $repoName \
    --path $path \
    --dest-namespace $namespace \
    --dest-server $destinationServer \
    --sync-policy $syncPolicy \
    --grpc-web
fi

# View app status
argocd app get $appName --grpc-web

# The application status is initially in OutOfSync state since the application has yet to be deployed,
# and no Kubernetes resources have been created. To sync (deploy) the application, run the sync command.
# This command retrieves the manifests from the repository and performs a kubectl apply of the manifests.
# The guestbook app is now running and you can now view its resource components, logs, events, and assessed health status.
argocd app sync $appName --grpc-web
