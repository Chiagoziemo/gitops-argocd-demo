# Analysis Templates

Cluster-scoped `AnalysisTemplate` resources consumed by `environments/base/demo-app/rollout.yaml` during each canary step. Kept separate from the workload so they can be reused by future services without duplication.

| Template | Metric | Threshold | Rationale |
|---|---|---|---|
| `success-rate` | non-5xx request ratio, 1m rate window | `>= 0.95` | Mirrors a typical availability SLO. Below 95% over 3 consecutive 15s checks, the analysis run is marked `Failed`. |
| `latency-p99` | p99 request duration, 1m rate window | `<= 0.25s` | Deliberately tight for the demo so `scripts/inject-failure.sh` trips it fast. In production this should come from historical p99 + a margin, not be picked arbitrarily. |

Both templates query the `kube-prometheus-stack-prometheus` Service installed by `bootstrap/03-install-prometheus-stack.sh`, and expect the workload to export standard `http_requests_total{code}` and `http_request_duration_seconds_bucket` metrics (see `demo-app/main.go`).

`failureLimit: 3` means the AnalysisRun tolerates transient blips (a GC pause, a cold cache) without false-positive rollbacks, while still catching a sustained regression within ~45-60 seconds of the canary receiving traffic.
