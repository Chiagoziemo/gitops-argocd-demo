#!/usr/bin/env bash
# Installs the Argo Rollouts controller and kubectl plugin manifests.
set -euo pipefail

ROLLOUTS_VERSION="${ROLLOUTS_VERSION:-stable}"

kubectl apply -n argo-rollouts -f "https://github.com/argoproj/argo-rollouts/releases/${ROLLOUTS_VERSION}/download/install.yaml"

echo "Waiting for the rollouts controller to become available..."
kubectl -n argo-rollouts rollout status deployment/argo-rollouts --timeout=180s

echo "Install the kubectl plugin separately if you want live rollout dashboards:"
echo "  kubectl krew install argo-rollouts   # or download the binary from the releases page"
