#!/bin/bash

CLUSTER_NAME="kind-local-1"

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
  kind create cluster --name $CLUSTER_NAME --config ../kind/local-1-kind-config.yaml
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
  kubectl create secret generic sops-age --namespace=flux-system --from-file=age.agekey=$HOME/.config/sops/age/kind-local-1.txt
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
    --path=clusters/staging/kind-local-1 \
    --components-extra image-reflector-controller,image-automation-controller
}

function check_trivy_vulnerability_reports() {
  NAMESPACE="examples"
  LABEL="trivy-operator.container.name=echo-values"
  MAX_WAIT_TIME=300  # 5 minutes in seconds
  INTERVAL=30        # Check every 30 seconds
  ELAPSED_TIME=0

  echo "Checking for existing Trivy vulnerability reports in namespace $NAMESPACE..."
  if kubectl get vulnerabilityreports -n $NAMESPACE &> /dev/null; then
    echo "Vulnerability reports already exist in namespace $NAMESPACE. Exiting."
    return 1
  else
    echo "No vulnerability reports found in namespace $NAMESPACE."
  fi

  echo "Polling every $INTERVAL seconds to check for a vulnerability report with label $LABEL (timeout: $MAX_WAIT_TIME seconds)..."
  while [ $ELAPSED_TIME -lt $MAX_WAIT_TIME ]; do
    REPORT=$(kubectl get vulnerabilityreports -n $NAMESPACE -l $LABEL -o jsonpath='{.items[*].metadata.name}')
    if [ -n "$REPORT" ]; then
      echo "Vulnerability report with label $LABEL found: $REPORT"
      break
    else
      echo "No vulnerability report with label $LABEL found. Checking again in $INTERVAL seconds..."
      sleep $INTERVAL
      ELAPSED_TIME=$((ELAPSED_TIME + INTERVAL))
    fi
  done

  if [ $ELAPSED_TIME -ge $MAX_WAIT_TIME ]; then
    echo "Timeout reached: No vulnerability report with label $LABEL found after $MAX_WAIT_TIME seconds."
    return 1
  fi
}

check_preconditions
create_cluster
init_flux_namespace
bootstrap_flux
check_trivy_vulnerability_reports