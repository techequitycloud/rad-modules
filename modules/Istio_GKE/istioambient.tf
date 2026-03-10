/**
 * Copyright 2025 Tech Equity Ltd
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
 
resource "null_resource" "install_ambient_mesh" {
  count = var.install_ambient_mesh ? 1 : 0 

  triggers = {
    # always_run                = timestamp()
    istio_path                = "$HOME/istio-${var.istio_version}"
    cluster_name              = var.gke_cluster
    region                    = var.gcp_region
    project_id                = local.project.project_id
    istio_release             = regex("^(\\d+\\.\\d+)", var.istio_version)[0]
    istio_version             = var.istio_version
    resource_creator_identity = var.resource_creator_identity  # Added for destroy provisioner
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<-EOF
    set -eo pipefail
    echo "=== Installing Istio ${var.istio_version} (Ambient Mode) ==="
    
    # Create local bin directory if it doesn't exist
    mkdir -p $HOME/.local/bin
    export PATH=$HOME/.local/bin:$PATH
    
    # Check if kubectl is available, if not install it
    if ! command -v kubectl &> /dev/null; then
      echo "kubectl not found, installing..."
      # Detect OS and architecture for kubectl
      OS=$(uname -s | tr '[:upper:]' '[:lower:]')
      ARCH=$(uname -m)
      case $ARCH in
        x86_64) ARCH="amd64" ;;
        arm64|aarch64) ARCH="arm64" ;;
        *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
      esac
      
      # Download kubectl to local bin
      curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/$OS/$ARCH/kubectl"
      chmod +x kubectl
      mv kubectl $HOME/.local/bin/
      echo "kubectl installed to $HOME/.local/bin/"
    fi
    
    # Verify kubectl is now available
    if ! command -v kubectl &> /dev/null; then
      echo "kubectl still not found in PATH. Current PATH: $PATH"
      exit 1
    fi
    
    # Detect OS and architecture for Istio
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)
    case $ARCH in
      x86_64) ARCH="amd64" ;;
      arm64|aarch64) ARCH="arm64" ;;
      *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
    esac
    case $OS in
      darwin) OS_SUFFIX="osx" ;;
      linux) OS_SUFFIX="linux" ;;
      *) echo "Unsupported OS: $OS"; exit 1 ;;
    esac

    # Download and extract Istio
    echo "Downloading Istio ${var.istio_version} for $OS_SUFFIX-$ARCH..."
    cd $HOME
    curl -fL https://github.com/istio/istio/releases/download/${var.istio_version}/istio-${var.istio_version}-$OS_SUFFIX-$ARCH.tar.gz \
      | tar xz || { echo "Failed to download/extract Istio"; exit 1; }
        
    # Use actual extracted path, not trigger variable
    export PATH=$HOME/istio-${var.istio_version}/bin:$PATH
    cd $HOME/istio-${var.istio_version}

    # Configure GKE cluster access with conditional impersonation
    echo "Configuring cluster access..."
    gcloud container clusters get-credentials ${var.gke_cluster} \
      --region ${var.gcp_region} \
      --project ${local.project.project_id} \
      ${var.resource_creator_identity != "" ? "--impersonate-service-account=${var.resource_creator_identity}" : ""} || \
      { echo "Failed to get cluster credentials"; exit 1; }

    # Wait for cluster to be ready
    echo "Waiting for cluster to be ready..."
    kubectl wait --for=condition=Ready nodes --all --timeout=300s || {
      echo "Warning: Timeout waiting for nodes to be ready, continuing..."
    }

    # Create Istio system namespace if it doesn't exist
    echo "Creating istio-system namespace..."
    kubectl create namespace istio-system --dry-run=client -o yaml | kubectl apply -f -
    
    # Apply resource quota
    echo "Applying resource quota..."
    cat <<EOS | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: gcp-critical-pods
  namespace: istio-system
spec:
  hard:
    pods: 1G
  scopeSelector:
    matchExpressions:
    - operator: In
      scopeName: PriorityClass
      values:
      - system-node-critical
EOS

    # Install Istio with ambient profile
    echo "Installing Istio with ambient profile..."
    istioctl install -y \
      --set profile=ambient \
      --set "components.ingressGateways[0].enabled=true" \
      --set "components.ingressGateways[0].name=istio-ingressgateway" \
      --set "components.ingressGateways[0].k8s.service.type=LoadBalancer" \
      --skip-confirmation || \
      { echo "Istio ambient installation failed"; exit 1; }

    # Wait for Istio control plane to be ready
    echo "Waiting for Istio control plane to be ready..."
    kubectl wait --for=condition=Available deployment/istiod -n istio-system --timeout=300s || {
      echo "Warning: Timeout waiting for istiod, continuing..."
    }

    # Wait for ingress gateway to be ready
    echo "Waiting for ingress gateway to be ready..."
    kubectl wait --for=condition=Available deployment/istio-ingressgateway -n istio-system --timeout=300s || {
      echo "Warning: Timeout waiting for ingress gateway, continuing..."
    }

    # Configure default namespace for ambient mode
    echo "Configuring default namespace for ambient mode..."
    kubectl label namespace default istio.io/dataplane-mode=ambient --overwrite

    # Apply waypoint proxy for default namespace
    echo "Applying waypoint proxy..."
    istioctl waypoint apply --namespace default || \
      echo "Warning: Waypoint configuration failed, continuing..."

    # Install observability addons with retries
    echo "Installing observability addons..."
    ISTIO_RELEASE=$(echo "${var.istio_version}" | cut -d. -f1,2)
    for addon in prometheus jaeger grafana kiali; do
      echo "Installing $addon..."
      kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-$ISTIO_RELEASE/samples/addons/$addon.yaml || \
        echo "Warning: Failed to install $addon"
      sleep 5
    done

    # Verify installation
    echo "Verifying Istio ambient installation..."
    istioctl verify-install || echo "Warning: Istio verification had issues"
    
    # Check ambient mode status
    echo "Checking ambient mode status..."
    kubectl get pods -n istio-system -l app=ztunnel || echo "Warning: No ztunnel pods found"
    
    echo "✓ Ambient mesh installation completed successfully"
    echo "✓ Istio control plane: $(kubectl get pods -n istio-system -l app=istiod --no-headers | wc -l) pods"
    echo "✓ Istio ingress gateway: $(kubectl get pods -n istio-system -l app=istio-ingressgateway --no-headers | wc -l) pods"
    echo "✓ Ztunnel pods: $(kubectl get pods -n istio-system -l app=ztunnel --no-headers | wc -l) pods"
    
    exit 0
    EOF

    environment = {
      KUBECONFIG = ""  # Use default kubeconfig location
    }
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    when    = destroy
    command = <<-EOF
      set +e  # Disable exit-on-error globally for this script
      echo "=== Uninstalling Istio Ambient Mesh (Graceful Mode) ==="
      
      # Set up environment
      export PATH=$HOME/.local/bin:$PATH
      ISTIO_PATH="${self.triggers.istio_path}"
      ISTIO_RELEASE="${self.triggers.istio_release}"
      
      # Configure cluster access for cleanup
      gcloud container clusters get-credentials ${self.triggers.cluster_name} \
        --region ${self.triggers.region} \
        --project ${self.triggers.project_id} \
        ${self.triggers.resource_creator_identity != "" ? "--impersonate-service-account=${self.triggers.resource_creator_identity}" : ""} 2>/dev/null || \
        echo "Warning: Failed to get cluster credentials for cleanup"
      
      # Remove waypoints first (ignore failures)
      if [ -f "$ISTIO_PATH/bin/istioctl" ]; then
        echo "Removing waypoint proxies..."
        $ISTIO_PATH/bin/istioctl waypoint delete --all -A 2>/dev/null || \
          echo "Warning: Waypoint cleanup encountered errors"
      fi

      # Remove namespace labels (ignore missing resources)
      echo "Removing namespace labels..."
      kubectl label namespace default istio.io/dataplane-mode- istio.io/use-waypoint- --overwrite --ignore-not-found 2>/dev/null || \
        echo "Warning: Failed to remove namespace labels"

      # Remove addons (ignore missing manifests)
      echo "Removing observability addons..."
      for addon in kiali grafana jaeger prometheus; do
        kubectl delete -f https://raw.githubusercontent.com/istio/istio/release-$ISTIO_RELEASE/samples/addons/$addon.yaml \
          --ignore-not-found --timeout=60s 2>/dev/null || \
          echo "Warning: Failed to remove $addon"
      done

      # Cleanup Istio installation (ignore failures)
      if [ -f "$ISTIO_PATH/bin/istioctl" ]; then
        echo "Uninstalling Istio..."
        $ISTIO_PATH/bin/istioctl uninstall --purge -y 2>/dev/null || \
          echo "Warning: Istio uninstall encountered errors (possibly already removed)"
      else
        echo "Warning: istioctl not found at $ISTIO_PATH/bin/istioctl"
      fi

      # Cleanup system resources (ignore missing namespace)
      echo "Removing istio-system namespace..."
      kubectl delete namespace istio-system --ignore-not-found --timeout=120s 2>/dev/null || \
        echo "Warning: Failed to remove istio-system namespace"
      
      # Remove Istio directory
      if [ -d "$ISTIO_PATH" ]; then
        echo "Removing Istio directory..."
        rm -rf "$ISTIO_PATH" 2>/dev/null || \
          echo "Warning: Failed to remove Istio directory (may not exist)"
      fi
      
      echo "✓ Ambient mesh uninstallation completed (gracefully)"
      exit 0
    EOF
  }

  depends_on = [
    google_container_node_pool.preemptible_nodes,
    google_container_cluster.gke_standard_cluster,
  ]
}

# Output Istio ingress gateway external IP for ambient mesh
resource "null_resource" "get_ambient_istio_ingress_ip" {
  count = var.install_ambient_mesh ? 1 : 0
  
  depends_on = [null_resource.install_ambient_mesh]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<-EOT
      echo "Waiting for Istio ingress gateway external IP..."
      export PATH=$HOME/.local/bin:$PATH
      
      for i in {1..30}; do
        EXTERNAL_IP=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
        if [ ! -z "$EXTERNAL_IP" ] && [ "$EXTERNAL_IP" != "null" ]; then
          echo "Istio Ingress Gateway External IP: $EXTERNAL_IP"
          break
        fi
        echo "Waiting for external IP... (attempt $i/30)"
        sleep 10
      done
      
      # Show ambient mesh status
      echo "=== Ambient Mesh Status ==="
      kubectl get pods -n istio-system -l app=ztunnel 2>/dev/null || echo "No ztunnel pods found"
      kubectl get namespace default --show-labels 2>/dev/null | grep istio.io/dataplane-mode || echo "Default namespace not configured for ambient mode"
    EOT
  }
}
