#!/bin/bash

CLUSTER_NAME="kind-local-4"

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

function test_rbac() {
  echo "Testing RBAC configuration..."
  
  # Save current context
  ORIGINAL_USER=$(kubectl config view --minify -o jsonpath='{.contexts[0].context.user}')
  
  # Set up test user context
  kubectl config set-context kind-${CLUSTER_NAME} --user=test-user
  kubectl config set-credentials test-user --token=Token456
  
  echo "Testing pod-reader permissions..."
  
  # Test 1: Should be able to read pods
  if kubectl get pods -A &>/dev/null; then
    echo "✓ Pod reading test passed"
  else
    echo "✗ Pod reading test failed"
    # Restore original user
    kubectl config set-context kind-${CLUSTER_NAME} --user=${ORIGINAL_USER}
    exit 1
  fi
  
  # Test 2: Should NOT be able to read configmaps
  if kubectl get configmaps -A &>/dev/null; then
    echo "✗ ConfigMap reading test failed (should have been denied)"
    # Restore original user
    kubectl config set-context kind-${CLUSTER_NAME} --user=${ORIGINAL_USER}
    exit 1
  else
    echo "✓ ConfigMap reading test passed (correctly denied)"
  fi
  
  # Test auth whoami
  echo "Testing auth whoami..."
  WHOAMI_OUTPUT=$(kubectl auth whoami 2>/dev/null)
  if echo "$WHOAMI_OUTPUT" | grep -q "pod-reader"; then
    echo "✓ Auth whoami test passed: $WHOAMI_OUTPUT"
  else
    echo "✗ Auth whoami test failed: $WHOAMI_OUTPUT"
    # Restore original user
    kubectl config set-context kind-${CLUSTER_NAME} --user=${ORIGINAL_USER}
    exit 1
  fi
  
  # Restore original user
  kubectl config set-context kind-${CLUSTER_NAME} --user=${ORIGINAL_USER}
  
  echo "All RBAC tests passed successfully!"
}

check_preconditions
create_cluster
init_flux_namespace
bootstrap_flux
test_rbac
