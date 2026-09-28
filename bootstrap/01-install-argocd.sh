#!/usr/bin/env bash
# Installs ArgoCD (upstream stable manifests) into the argocd namespace.
set -euo pipefail

ARGOCD_VERSION="${ARGOCD_VERSION:-stable}"

kubectl apply -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml" -n argocd

echo "Waiting for ArgoCD server to become available..."
kubectl -n argocd rollout status deployment/argocd-server --timeout=180s

echo "Initial admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
echo
echo "Port-forward with: kubectl -n argocd port-forward svc/argocd-server 8081:443"
