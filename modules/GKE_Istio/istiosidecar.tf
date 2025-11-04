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

resource "null_resource" "install_sidecar_mesh" {
  count = var.install_ambient_mesh ? 0 : 1

  triggers = {
    istio_path                = "$HOME/istio-${var.istio_version}"
    cluster_name              = var.gke_cluster
    region                    = var.region
    project_id                = local.project.project_id
    istio_release             = regex("^(\\d+\\.\\d+)", var.istio_version)[0]
    istio_version             = var.istio_version
    resource_creator_identity = var.resource_creator_identity
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command = <<-EOF
    set -eo pipefail
    echo "=== Installing Istio ${var.istio_version} (Sidecar Mode) ==="

    # Source the setup script to inherit environment variables
    source "${path.module}/scripts/setup_istio.sh" "${var.istio_version}"
    
    # Verify istioctl is now available
    if ! command -v istioctl &> /dev/null; then
      echo "ERROR: istioctl not found after setup"
      echo "Current PATH: $PATH"
      exit 1
    fi

    # Ensure gcloud is authenticated
    echo "Verifying gcloud authentication..."
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null | grep -q .; then
      echo "ERROR: No active gcloud account found"
      echo "Please ensure you are authenticated with gcloud"
      exit 1
    fi

    ACTIVE_ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")
    echo "✓ Using gcloud account: $ACTIVE_ACCOUNT"

    # Define impersonation flag
    IMPERSONATE_FLAG=""
    if [ -n "${var.resource_creator_identity}" ]; then
      IMPERSONATE_FLAG="--impersonate-service-account=${var.resource_creator_identity}"
      echo "Using service account impersonation: ${var.resource_creator_identity}"
    fi

    # Configure GKE cluster access with explicit project
    echo "Configuring cluster access..."
    gcloud container clusters get-credentials ${var.gke_cluster} \
      --region ${var.region} \
      --project ${local.project.project_id} \
      $IMPERSONATE_FLAG || \
      { echo "Failed to get cluster credentials"; exit 1; }

    # Verify kubectl can connect
    echo "Verifying kubectl connectivity..."
    if ! kubectl cluster-info &>/dev/null; then
      echo "ERROR: Cannot connect to cluster"
      kubectl cluster-info
      exit 1
    fi
    echo "✓ kubectl connected to cluster"

    # Wait for cluster to be ready
    echo "Waiting for cluster to be ready..."
    kubectl wait --for=condition=Ready nodes --all --timeout=300s || {
      echo "Warning: Timeout waiting for nodes to be ready, continuing..."
    }

    # Create istio-system namespace first
    echo "Creating istio-system namespace..."
    kubectl create namespace istio-system --dry-run=client -o yaml | kubectl apply -f -

    # Step 1: Install ONLY the base (CRDs) using istioctl with explicit settings
    echo "Step 1: Installing Istio CRDs (base component only)..."
    
    # Use a temporary IstioOperator manifest for base installation
    cat <<BASE_CONFIG > /tmp/istio-base.yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  name: istio-base
  namespace: istio-system
spec:
  profile: minimal
  components:
    base:
      enabled: true
    pilot:
      enabled: false
    ingressGateways:
    - name: istio-ingressgateway
      enabled: false
    egressGateways:
    - name: istio-egressgateway
      enabled: false
  values:
    global:
      istioNamespace: istio-system
BASE_CONFIG

    # Install base with explicit kubeconfig
    istioctl install -y -f /tmp/istio-base.yaml --skip-confirmation || {
      echo "ERROR: Failed to install Istio base/CRDs"
      echo "Checking kubectl access..."
      kubectl get nodes
      kubectl get namespaces
      exit 1
    }

    echo "✓ Istio base/CRDs installed successfully"

    # Step 2: Wait for ALL CRDs to be established
    echo "Step 2: Waiting for Istio CRDs to be fully established..."
    CRDS=(
      "destinationrules.networking.istio.io"
      "virtualservices.networking.istio.io"
      "gateways.networking.istio.io"
      "serviceentries.networking.istio.io"
      "workloadentries.networking.istio.io"
      "workloadgroups.networking.istio.io"
      "sidecars.networking.istio.io"
      "envoyfilters.networking.istio.io"
      "proxyconfigs.networking.istio.io"
      "peerauthentications.security.istio.io"
      "requestauthentications.security.istio.io"
      "authorizationpolicies.security.istio.io"
      "telemetries.telemetry.istio.io"
      "wasmplugins.extensions.istio.io"
    )

    for crd in "$${CRDS[@]}"; do
      echo "Waiting for CRD: $crd"
      kubectl wait --for condition=established --timeout=120s crd/$crd || {
        echo "ERROR: CRD $crd failed to establish"
        kubectl get crd $crd -o yaml || true
        exit 1
      }
    done

    # Step 3: Verify CRDs are queryable
    echo "Step 3: Verifying CRDs are queryable..."
    sleep 10  # Give API server extra time
    
    for crd in "$${CRDS[@]}"; do
      RESOURCE=$(echo $crd | cut -d. -f1)
      APIGROUP=$(echo $crd | cut -d. -f2-)
      echo "Testing query: $RESOURCE.$APIGROUP"
      kubectl get $RESOURCE.$APIGROUP --all-namespaces 2>&1 | head -n 1 || {
        echo "WARNING: CRD $crd not yet queryable, waiting longer..."
        sleep 5
      }
    done

    echo "✓ All CRDs are established and queryable"

    # Step 4: Now install the control plane
    echo "Step 4: Installing Istio control plane (without base)..."
    cat <<ISTIO_CONFIG > /tmp/istio-control-plane.yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  name: control-plane
  namespace: istio-system
spec:
  profile: minimal
  hub: docker.io/istio
  tag: ${var.istio_version}
  values:
    global:
      meshID: mesh1
      multiCluster:
        clusterName: cluster1
      network: network1
  components:
    base:
      enabled: false  # CRDs already installed in step 1
    pilot:
      enabled: true
      k8s:
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
        env:
        - name: PILOT_ENABLE_STATUS
          value: "true"
    ingressGateways:
    - name: istio-ingressgateway
      enabled: true
      k8s:
        service:
          type: LoadBalancer
        hpaSpec:
          minReplicas: 1
          maxReplicas: 5
          scaleTargetRef:
            apiVersion: apps/v1
            kind: Deployment
            name: istio-ingressgateway
          metrics:
          - type: Resource
            resource:
              name: cpu
              target:
                type: Utilization
                averageUtilization: 80
ISTIO_CONFIG

    istioctl install -y -f /tmp/istio-control-plane.yaml --skip-confirmation || {
      echo "Istio installation with custom config failed, trying minimal installation..."
      istioctl install -y --set profile=minimal \
        --set hub=docker.io/istio --set tag=${var.istio_version} \
        --set "components.base.enabled=false" \
        --set "components.pilot.enabled=true" \
        --set "components.ingressGateways[0].enabled=true" \
        --set "components.ingressGateways[0].name=istio-ingressgateway" \
        --set "components.ingressGateways[0].k8s.service.type=LoadBalancer" \
        --skip-confirmation || \
        { echo "Istio minimal installation also failed"; exit 1; }
    }

    # Clean up temp files
    rm -f /tmp/istio-base.yaml /tmp/istio-control-plane.yaml

    # Step 5: Wait for control plane to be ready
    echo "Step 5: Waiting for Istio control plane to be ready..."
    kubectl wait --for=condition=Available deployment/istiod -n istio-system --timeout=300s || {
      echo "ERROR: Timeout waiting for istiod"
      kubectl get pods -n istio-system
      kubectl logs -n istio-system -l app=istiod --tail=100 || true
      exit 1
    }

    # Check for CRD errors in logs
    echo "Checking istiod logs for CRD errors..."
    if kubectl logs -n istio-system -l app=istiod --tail=50 | grep -i "could not find the requested resource"; then
      echo "ERROR: istiod still has CRD-related errors"
      kubectl logs -n istio-system -l app=istiod --tail=100
      exit 1
    else
      echo "✓ No CRD-related errors in istiod logs"
    fi

    # Step 6: Wait for ingress gateway to be ready
    echo "Step 6: Waiting for ingress gateway to be ready..."
    kubectl wait --for=condition=Available deployment/istio-ingressgateway -n istio-system --timeout=300s || {
      echo "Warning: Timeout waiting for ingress gateway"
      kubectl get pods -n istio-system -l app=istio-ingressgateway
    }

    # Enable sidecar injection for default namespace
    echo "Enabling sidecar injection for default namespace..."
    kubectl label namespace default istio-injection=enabled --overwrite

    # Install observability addons
    echo "Installing observability addons..."
    ISTIO_RELEASE=$(echo "${var.istio_version}" | cut -d. -f1,2)
    for addon in prometheus jaeger grafana kiali; do
      echo "Installing $addon..."
      kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-$ISTIO_RELEASE/samples/addons/$addon.yaml || \
        echo "Warning: Failed to install $addon"
      sleep 5
    done

    # Final verification
    echo "Verifying Istio installation..."
    istioctl verify-install || echo "Warning: Istio verification had issues"
    
    echo ""
    echo "=========================================="
    echo "✓ Sidecar mesh installation completed successfully"
    echo "=========================================="
    echo "✓ Istio CRDs: $(kubectl get crd | grep istio.io | wc -l) installed"
    echo "✓ Istio control plane: $(kubectl get pods -n istio-system -l app=istiod --no-headers | wc -l) pods"
    echo "✓ Istio ingress gateway: $(kubectl get pods -n istio-system -l app=istio-ingressgateway --no-headers | wc -l) pods"
    echo "=========================================="
    
    exit 0
    EOF

    # Don't override KUBECONFIG - let it use the default with gcloud credentials
    environment = {
      USE_GKE_GCLOUD_AUTH_PLUGIN = "True"
    }
  }

  provisioner "local-exec" {
    when = destroy
    command = <<-EOF
      set +e
      echo "=== Uninstalling Istio Sidecar Mesh (Graceful Mode) ==="
      
      export PATH=$HOME/.local/bin:$PATH
      export USE_GKE_GCLOUD_AUTH_PLUGIN=True
      ISTIO_PATH="${self.triggers.istio_path}"
      ISTIO_RELEASE="${self.triggers.istio_release}"
      
      IMPERSONATE_FLAG=""
      if [ -n "${self.triggers.resource_creator_identity}" ]; then
        IMPERSONATE_FLAG="--impersonate-service-account=${self.triggers.resource_creator_identity}"
      fi

      gcloud container clusters get-credentials ${self.triggers.cluster_name} \
        --region ${self.triggers.region} \
        --project ${self.triggers.project_id} \
        $IMPERSONATE_FLAG || \
        echo "Warning: Failed to get cluster credentials for cleanup"

      kubectl label namespace default istio-injection- --overwrite --ignore-not-found || \
        echo "Warning: Failed to remove namespace labels"

      for addon in kiali grafana jaeger prometheus; do
        kubectl delete -f https://raw.githubusercontent.com/istio/istio/release-$ISTIO_RELEASE/samples/addons/$addon.yaml \
          --ignore-not-found --timeout=60s || \
          echo "Warning: Failed to remove $addon"
      done

      if [ -f "$ISTIO_PATH/bin/istioctl" ]; then
        $ISTIO_PATH/bin/istioctl uninstall --purge -y || \
          echo "Warning: Istio uninstall encountered errors"
      fi

      kubectl delete namespace istio-system --ignore-not-found --timeout=120s || \
        echo "Warning: Failed to remove istio-system namespace"

      [ -d "$ISTIO_PATH" ] && rm -rf "$ISTIO_PATH" || true
      
      echo "✓ Sidecar mesh uninstallation completed"
      exit 0
    EOF
  }

  depends_on = [
    google_container_node_pool.preemptible_nodes,
    google_container_cluster.gke_standard_cluster,
    time_sleep.wait_for_istio_uninstall,
  ]
}
