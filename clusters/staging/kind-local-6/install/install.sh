#!/bin/bash

CLUSTER_NAME="kind-local-6"
MISSING_TOOLS=()

function check_preconditions() {
  if ! command -v kind &> /dev/null; then
    MISSING_TOOLS+=("kind")
  fi

  if ! command -v kubectl &> /dev/null; then
    MISSING_TOOLS+=("kubectl")
  fi

  if [ ${#MISSING_TOOLS[@]} -ne 0 ]; then
    echo "The following tools are missing: ${MISSING_TOOLS[*]}"
    exit 1
  fi
}

# Function to retry a command with a maximum number of attempts
# Parameters:
#   $1: Description of the operation
#   $2: Command to execute (should be a function name)
#   $3: Error message if all attempts fail
retry_with_attempts() {
    local desc="$1"
    local cmd="$2"
    local error_msg="$3"
    local max_attempts=10
    local attempt=1

    echo "Waiting for $desc..."
    while [ $attempt -le $max_attempts ]; do
        if eval "$cmd"; then
            echo "✅ $desc successful!"
            return 0
        else
            echo "Attempt $attempt of $max_attempts: $desc not ready yet, waiting 10 seconds..."
            if [ $attempt -eq $max_attempts ]; then
                echo "ERROR: $error_msg"
                return 1
            fi
            sleep 10
            ((attempt++))
        fi
    done
}

# Define test functions for retry_with_attempts
wait_calico_pods() {
    kubectl wait --namespace calico-system --for=condition=ready pods --all --timeout=30s
}

wait_test_pod() {
    kubectl wait --for=condition=ready pod/test-pod --timeout=30s
}

test_network_connectivity() {
    kubectl exec test-pod -- ping -c 4 8.8.8.8 > /dev/null
}

function create_cluster() {
  if kind get clusters | grep -q $CLUSTER_NAME; then
    echo "Cluster with the name $CLUSTER_NAME already exists"
    return 0
  fi
  kind create cluster --name $CLUSTER_NAME --config ../kind/local-6-kind-config.yaml
}

function install_calico() {
  if ! kubectl get namespace calico-system &> /dev/null; then
    echo "Installing Calico..."
    # Install Calico operator
    kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/tigera-operator.yaml
    # Install Calico custom resources
    kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/custom-resources.yaml
  else
    echo "Calico is already installed"
    return 0
  fi
}

function verify_calico() {
  # Wait for calico-system namespace to be created
  echo "Waiting for calico-system namespace to be created..."
  while ! kubectl get namespace calico-system >/dev/null 2>&1; do
      sleep 2
  done

  # Wait for Calico pods to start appearing
  echo "Waiting for Calico pods to be created..."
  while [ $(kubectl get pods -n calico-system --no-headers 2>/dev/null | wc -l) -eq 0 ]; do
      sleep 2
  done

  # Create test pod
  echo "Creating test pod for network testing..."
  kubectl run test-pod --image=busybox --command -- sleep 3600 &

  # Wait for all components using retry function
  retry_with_attempts "Calico pods to be ready" wait_calico_pods "Calico pods failed to become ready" || exit 1
  retry_with_attempts "test pod to be ready" wait_test_pod "Test pod failed to become ready" || { kubectl delete pod test-pod; exit 1; }
  retry_with_attempts "network connectivity" test_network_connectivity "Network connectivity test failed" || { kubectl delete pod test-pod; exit 1; }

  # Clean up test pod
  kubectl delete pod --force --grace-period=0 test-pod 

  echo "✅ Calico is properly installed and functioning!"
}

# Main execution flow
check_preconditions
create_cluster
install_calico
verify_calico

echo "Kind cluster with Calico has been successfully created and verified!"
