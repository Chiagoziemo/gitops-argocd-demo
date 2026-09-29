#!/usr/bin/env bash
# Points Argo CD at this repo's app-of-apps root. From here on, every other
# Application (the demo app, the analysis templates) is managed
# declaratively by Argo CD -- this is the one and only imperative apply.
#
# apps/root-app.yaml and apps/child-apps/*.yaml all hardcode this repo's
# actual GitHub URL rather than templating it at apply time: the child
# Application manifests are read by Argo CD directly from git, never through
# this script, so a local sed substitution here can't reach them anyway --
# fork this repo and update repoURL in those three files if you're
# replicating it under your own account.
set -euo pipefail

kubectl apply -n argocd -f "$(dirname "$0")/../apps/root-app.yaml"

echo "Root Application applied. Watch it sync with:"
echo "  kubectl -n argocd get applications -w"
