#!/usr/bin/env bash
# Live dashboard of the current Rollout: revisions, ReplicaSet weights,
# and pod health. Run this in a second terminal while inject-failure.sh
# (or a real git push) drives a new revision through canary analysis.
set -euo pipefail

NAMESPACE="${NAMESPACE:-demo-app}"

kubectl argo rollouts get rollout demo-app -n "$NAMESPACE" --watch
