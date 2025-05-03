#!/bin/bash

CLUSTER_NAME="kind-local-5"

function check_preconditions() {
  if ! command -v kind &> /dev/null; then
    MISSING_TOOLS+=("kind")
  fi

  if ! command -v kubectl &> /dev/null; then
    MISSING_TOOLS+=("kubectl")
  fi

  if ! command -v flux &> /dev/null; then
    MISSING_TOOLS+=("flux")
  fi

  if ! command -v sops &> /dev/null; then
    MISSING_TOOLS+=("sops")
  fi

  if [ ${#MISSING_TOOLS[@]} -ne 0 ]; then
    echo "The following tools are missing: ${MISSING_TOOLS[*]}"
    exit 1
  fi
}

function create_cluster() {
  if kind get clusters | grep -q $CLUSTER_NAME; then
    echo "Cluster with the name $CLUSTER_NAME already exists"
    return 0
  fi
  kind create cluster --name $CLUSTER_NAME --config ../kind/${CLUSTER_NAME}.yaml
}

function init_flux_namespace() {
  if kubectl get namespace flux-system &> /dev/null; then
    echo "Namespace flux-system already exists"
    return 0
  fi
  kubectl create namespace flux-system

  if kubectl get secret sops-age --namespace=flux-system &> /dev/null; then
    echo "Secret sops-age already exists in namespace flux-system"
    return 0
  fi
  kubectl create secret generic sops-age --namespace=flux-system --from-file=age.agekey=$HOME/.config/sops/age/${CLUSTER_NAME}.txt
}

function bootstrap_flux() {
  ALL_PODS=$(kubectl get pods --namespace=flux-system -o jsonpath='{.items[*].metadata.name}')
  PODS_NOT_RUNNING=$(kubectl get pods --namespace=flux-system -o jsonpath='{.items[?(@.status.phase != "Running")].metadata.name}')

  if [ -z "$ALL_PODS" ] || [ -n "$PODS_NOT_RUNNING" ]; then
    echo "Flux is not yet bootstrapped. Bootstrapping..."
  else
    echo "Flux is already running"
    return 0
  fi

  if [ -z "$GITHUB_TOKEN" ]; then
    echo "Please set the GITHUB_TOKEN environment variable"
    exit 1
  fi

  flux bootstrap git \
    --url=https://github.com/CICDior/fleet-infra.git \
    --username=tom1299 \
    --password="$GITHUB_TOKEN" \
    --token-auth=true \
    --path=clusters/staging/${CLUSTER_NAME} \
    --components-extra image-reflector-controller,image-automation-controller
}

function install_kubeflow_pipelines() {
  export PIPELINE_VERSION=2.3.0
  kubectl apply -k "github.com/kubeflow/pipelines/manifests/kustomize/cluster-scoped-resources?ref=$PIPELINE_VERSION"
  kubectl wait --for condition=established --timeout=60s crd/applications.app.k8s.io
  kubectl apply -k "github.com/kubeflow/pipelines/manifests/kustomize/env/dev?ref=$PIPELINE_VERSION"
}

check_preconditions
create_cluster
init_flux_namespace
bootstrap_flux
install_kubeflow_pipelines
