#!/bin/bash
set -eo pipefail

# This script sets up the environment for installing Istio.
# It installs kubectl if it's not already installed, and downloads the specified version of Istio.

# --- Helper Functions ---
log() {
  echo "--- $1 ---"
}

# --- Environment Setup ---
log "Setting up environment"
mkdir -p "$HOME/.local/bin"
export PATH="$HOME/.local/bin:$PATH"
export ISTIO_VERSION="${1}" # Use the first argument as the Istio version

# --- kubectl Installation ---
if ! command -v kubectl &> /dev/null; then
  log "kubectl not found, installing..."
  OS=$(uname -s | tr '[:upper:]' '[:lower:]')
  ARCH=$(uname -m)
  case $ARCH in
    x86_64) ARCH="amd64" ;;
    arm64|aarch64) ARCH="arm64" ;;
    *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
  esac

  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/$OS/$ARCH/kubectl"
  chmod +x kubectl
  mv kubectl "$HOME/.local/bin/"
  log "kubectl installed to $HOME/.local/bin/"
fi

# --- Istio Download ---
log "Downloading Istio $ISTIO_VERSION"
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

cd "$HOME"
curl -fL "https://github.com/istio/istio/releases/download/${ISTIO_VERSION}/istio-${ISTIO_VERSION}-${OS_SUFFIX}-${ARCH}.tar.gz" | tar xz

# --- Finalization ---
export PATH="$HOME/istio-${ISTIO_VERSION}/bin:$PATH"
cd "$HOME/istio-${ISTIO_VERSION}"
log "Istio setup complete"
