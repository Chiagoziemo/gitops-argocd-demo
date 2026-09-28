#!/usr/bin/env bash
# Points ArgoCD at this repo's app-of-apps root. From here on, every other
# Application (Prometheus, Argo Rollouts, the demo app itself) is managed
# declaratively by ArgoCD — this is the one and only imperative apply.
set -euo pipefail

REPO_URL="${REPO_URL:?Set REPO_URL to this repo's git remote, e.g. https://github.com/<you>/gitops-argocd-demo.git}"

sed "s#__REPO_URL__#${REPO_URL}#" "$(dirname "$0")/../apps/root-app.yaml" | kubectl apply -n argocd -f -

echo "Root Application applied. Watch it sync with:"
echo "  kubectl -n argocd get applications -w"
