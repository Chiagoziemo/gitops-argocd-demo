#!/usr/bin/env bash
# Triggers a new Rollout revision that fails its own SLO gates, so you can
# watch Argo Rollouts run the canary steps, fail the AnalysisRun, and
# auto-rollback -- without waiting on a container build/push cycle.
#
# This patches the live Rollout directly, which is deliberately NOT how you'd
# ship this in real life (see the note it prints below) -- it's a fast path
# for the demo. The real path is: edit environments/overlays/prod, commit,
# push, let ArgoCD sync.
set -euo pipefail

NAMESPACE="${NAMESPACE:-demo-app}"
FAILURE_RATE="${1:-0.4}"

echo "Rolling out a version with FAILURE_RATE=${FAILURE_RATE} to trigger canary analysis..."
kubectl -n "$NAMESPACE" patch rollout demo-app --type=json \
  -p="[{\"op\":\"add\",\"path\":\"/spec/template/spec/containers/0/env\",\"value\":[{\"name\":\"FAILURE_RATE\",\"value\":\"${FAILURE_RATE}\"},{\"name\":\"VERSION\",\"value\":\"v2-bad\"}]}]"

cat <<'EOF'

Watch it with:
  kubectl argo rollouts get rollout demo-app -n demo-app --watch

Expect: canary steps to 20% then 40% traffic, an AnalysisRun failing
success-rate and/or latency-p99 within a couple of 15s intervals, and Argo
Rollouts automatically aborting and scaling the canary ReplicaSet back to
zero -- no human in the loop.

NOTE: this patched the live cluster directly, bypassing git. ArgoCD's
self-heal will notice the drift from what's committed in
environments/overlays/prod and can revert it on the next reconcile -- run
`kubectl -n argocd get application demo-app` afterwards and watch its sync
status flip. That fight between an imperative patch and a self-healing
GitOps controller is itself worth narrating in the demo.
EOF
