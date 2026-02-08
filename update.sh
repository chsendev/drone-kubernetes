#!/bin/bash

if [ -z ${PLUGIN_NAMESPACE} ]; then
  PLUGIN_NAMESPACE="default"
fi

if [ -z ${PLUGIN_KUBERNETES_USER} ]; then
  PLUGIN_KUBERNETES_USER="default"
fi

if [ ! -z ${PLUGIN_KUBERNETES_TOKEN} ]; then
  KUBERNETES_TOKEN=$PLUGIN_KUBERNETES_TOKEN
fi

if [ ! -z ${PLUGIN_KUBERNETES_SERVER} ]; then
  KUBERNETES_SERVER=$PLUGIN_KUBERNETES_SERVER
fi

if [ ! -z ${PLUGIN_KUBERNETES_CERT} ]; then
  KUBERNETES_CERT=${PLUGIN_KUBERNETES_CERT}
fi

if [ -z "${PLUGIN_DEPLOYMENT}" ]; then
  echo "ERROR: PLUGIN_DEPLOYMENT is required"
  exit 1
fi

if [ -z "${PLUGIN_REPO}" ]; then
  echo "ERROR: PLUGIN_REPO is required"
  exit 1
fi

if [ -z "${PLUGIN_TAG}" ]; then
  echo "ERROR: PLUGIN_TAG is required"
  exit 1
fi

kubectl config set-credentials default --token=${KUBERNETES_TOKEN}
if [ ! -z ${KUBERNETES_CERT} ]; then
  echo ${KUBERNETES_CERT} | base64 -d > ca.crt
  kubectl config set-cluster default --server=${KUBERNETES_SERVER} --certificate-authority=ca.crt
else
  echo "WARNING: Using insecure connection to cluster"
  kubectl config set-cluster default --server=${KUBERNETES_SERVER} --insecure-skip-tls-verify=true
fi

kubectl config set-context default --cluster=default --user=${PLUGIN_KUBERNETES_USER}
kubectl config use-context default

# kubectl version
IFS=',' read -r -a DEPLOYMENTS <<< "${PLUGIN_DEPLOYMENT}"

DEPLOY_SUCCESS=false

for DEPLOY in ${DEPLOYMENTS[@]}; do
  echo "=========================================="
  echo "Processing deployment: ${DEPLOY}"
  
  if ! kubectl -n ${PLUGIN_NAMESPACE} get deployment/${DEPLOY} &> /dev/null; then
    echo "WARNING: Deployment ${DEPLOY} does not exist in namespace ${PLUGIN_NAMESPACE}, skipping..."
    echo "This is normal for first-time pipeline run. Please create the deployment manually or via KubeSphere UI first."
    continue
  fi
  
  echo "Deployment ${DEPLOY} found, proceeding with update..."
  
  if [ -z "${PLUGIN_CONTAINER}" ]; then
    echo "No container specified, using first container from deployment ${DEPLOY}"
    FIRST_CONTAINER=$(kubectl -n ${PLUGIN_NAMESPACE} get deployment/${DEPLOY} -o jsonpath='{.spec.template.spec.containers[0].name}')
    
    if [ -z "${FIRST_CONTAINER}" ]; then
      echo "WARNING: Failed to get container name from deployment ${DEPLOY}, skipping..."
      continue
    fi
    
    CONTAINERS=("${FIRST_CONTAINER}")
    echo "Using container: ${FIRST_CONTAINER}"
  else
    IFS=',' read -r -a CONTAINERS <<< "${PLUGIN_CONTAINER}"
  fi
  
  for CONTAINER in ${CONTAINERS[@]}; do
    if [[ ${PLUGIN_FORCE} == "true" ]]; then
      echo "Force updating image for ${CONTAINER} in deployment ${DEPLOY}"
      kubectl -n ${PLUGIN_NAMESPACE} set image deployment/${DEPLOY} \
        ${CONTAINER}=${PLUGIN_REPO}:${PLUGIN_TAG}FORCE
    fi
    
    echo "Updating image for ${CONTAINER} in deployment ${DEPLOY} to ${PLUGIN_REPO}:${PLUGIN_TAG}"
    if kubectl -n ${PLUGIN_NAMESPACE} set image deployment/${DEPLOY} \
      ${CONTAINER}=${PLUGIN_REPO}:${PLUGIN_TAG} --record; then
      echo "Successfully updated ${CONTAINER} in deployment ${DEPLOY}"
      DEPLOY_SUCCESS=true
    else
      echo "WARNING: Failed to update ${CONTAINER} in deployment ${DEPLOY}"
    fi
  done
done

echo "=========================================="
if [ "$DEPLOY_SUCCESS" = true ]; then
  echo "Deployment completed successfully"
  exit 0
else
  echo "WARNING: No deployments were updated. This might be the first pipeline run."
  echo "Please ensure deployments exist in namespace ${PLUGIN_NAMESPACE} before running this script."
  exit 0
fi
