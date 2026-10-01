# From-Scratch Setup Guide

A literal, tested, start-to-finish walkthrough for standing this whole thing up on a clean machine — through to triggering the failure-injection demo and watching the auto-rollback happen. Written from what actually happened building this repo, including the exact bugs that were hit and fixed along the way (see **Troubleshooting** at the bottom if something here doesn't match what you see).

Written for Windows (PowerShell + Git Bash). Swap the install commands for your OS if you're on Mac/Linux — everything past "prerequisites" is identical.

## What you'll end up with

- A 3-node `kind` Kubernetes cluster
- Argo CD managing everything via an App-of-Apps pattern
- Argo Rollouts running a canary release of a small Go service
- Prometheus gating each canary step against a success-rate and latency SLO
- The ability to ship a deliberately broken version and watch it get caught and rolled back automatically

Total time if all tools are already installed: ~10 minutes. With tool installs: ~25 minutes (Docker Desktop's install + a reboot is the long pole).

---

## 0. Prerequisites

Check what you already have first:

```powershell
docker ps
kind version
kubectl version --client
helm version
kubectl argo rollouts version
```

Install whatever's missing:

**Docker Desktop** — needed for `kind` (it runs cluster nodes as containers).
```powershell
winget install Docker.DockerDesktop
```
Launch it from the Start menu afterward and let it finish first-run setup (WSL2 backend, license). If you hit `MSI error 1603` during install, it almost always means a **pending reboot** — reboot the machine, then try again. Confirm it's actually working with `docker ps` (should return an empty table, not an error) before moving on.

**kind** — no clean Windows installer path, so grab the binary directly:
```powershell
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\bin" | Out-Null
Invoke-WebRequest -Uri "https://kind.sigs.k8s.io/dl/v0.24.0/kind-windows-amd64" -OutFile "$env:USERPROFILE\bin\kind.exe"
```

**kubectl** and **helm** — if missing:
```powershell
winget install Kubernetes.kubectl
winget install Helm.Helm
```

**kubectl argo rollouts plugin** — also a direct binary download. The filename matters: kubectl plugins use `kubectl-<name>`, and a multi-word plugin name uses an **underscore**, not a hyphen (`kubectl argo rollouts` → `kubectl-argo_rollouts`):
```powershell
Invoke-WebRequest -Uri "https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-windows-amd64" -OutFile "$env:USERPROFILE\bin\kubectl-argo_rollouts.exe"
```

**Put `~\bin` on your PATH permanently** (one-time, persists across all future shells — PowerShell, cmd, Git Bash):
```powershell
$binDir = "$env:USERPROFILE\bin"
$currentUserPath = [Environment]::GetEnvironmentVariable("PATH", "User")
if ($currentUserPath -notlike "*$binDir*") {
    [Environment]::SetEnvironmentVariable("PATH", "$currentUserPath;$binDir", "User")
}
```
**Open a new terminal window** after this — existing windows won't pick up the PATH change. Confirm with `kind --version` and `kubectl argo rollouts version` in the new window.

---

## 1. Get the repo

```bash
git clone https://github.com/Chiagoziemo/gitops-argocd-demo.git
cd gitops-argocd-demo
```

> Forking this under your own GitHub account instead? Argo CD reads the repo URL straight from the committed manifests, not from an env var — update `repoURL` in `apps/root-app.yaml`, `apps/child-apps/demo-app.yaml`, and `apps/child-apps/analysis-templates.yaml` to point at your fork before step 8.

---

## 2. Create the kind cluster

```bash
kind create cluster --config bootstrap/kind-cluster.yaml
kubectl apply -f bootstrap/00-namespaces.yaml
kubectl wait --for=condition=Ready nodes --all --timeout=90s
```

You should see 3 nodes (`gitops-demo-control-plane`, `gitops-demo-worker`, `gitops-demo-worker2`) go `Ready`.

---

## 3. Install the platform

These three install cluster-wide infrastructure imperatively (not via Argo CD — see the README's Decision Log #4 for why). Run them in order:

```bash
./bootstrap/01-install-argocd.sh
./bootstrap/02-install-argo-rollouts.sh
./bootstrap/03-install-prometheus-stack.sh
```

Each one waits for its own deployment to become available before returning, so they're safe to run back-to-back. The Argo CD script prints your admin password at the end — copy it, you'll need it for the UI later.

---

## 4. Build and load the demo app

`kind` doesn't pull from a registry by default — you build locally and load the image directly into the cluster's nodes:

```bash
docker build -t demo-app:latest demo-app/
kind load docker-image demo-app:latest --name gitops-demo
```

---

## 5. Bootstrap the App-of-Apps root

This is the one and only manual `kubectl apply` in the whole GitOps flow — everything after this point is managed by Argo CD syncing from git:

```bash
./bootstrap/04-bootstrap-root-app.sh
```

---

## 6. Verify everything's healthy

Give it 15-30 seconds to sync, then:

```bash
kubectl -n argocd get applications
```
All three (`root-app`, `demo-app`, `analysis-templates`) should read `Synced` / `Healthy`. If `demo-app` or `analysis-templates` stay `Unknown`, force a refresh:
```bash
kubectl -n argocd annotate application demo-app analysis-templates argocd.argoproj.io/refresh=hard --overwrite
```

Then check the Rollout itself:
```bash
kubectl argo rollouts get rollout demo-app -n demo-app
```
Expect `Status: ✔ Healthy`, `5/5` replicas available, single revision. First-ever deploy of a Rollout skips canary analysis entirely (nothing to canary against yet) and goes straight to steady state — that's expected, not a bug.

---

## 7. Open the UIs (optional, but worth it for a demo)

Each needs its own port-forward, left running in its own terminal:

```bash
# Argo Rollouts dashboard — best visual for the canary mechanics
kubectl argo rollouts dashboard -n demo-app
# → http://localhost:3100/rollouts

# Argo CD UI — the GitOps sync tree
kubectl -n argocd port-forward svc/argocd-server 8080:443
# → https://localhost:8080  (self-signed cert warning is expected)
# login: admin / <password printed by bootstrap/01-install-argocd.sh>

# Prometheus — the raw metrics behind the SLO gate
kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090
# → http://localhost:9090
```

---

## 8. Run the failure-injection demo

With everything healthy and (ideally) a UI open to watch:

```bash
NAMESPACE=demo-app ./scripts/inject-failure.sh 0.4
```

This ships a version with a 40% error rate. Watch it happen:

```bash
kubectl argo rollouts get rollout demo-app -n demo-app --watch
```

Expected sequence (takes 60-90 seconds):
1. Canary scales to 20% of pods (1 of 5).
2. 30s pause.
3. An `AnalysisRun` starts, querying Prometheus every 15s for success-rate and p99 latency.
4. Within 2-3 measurements, both metrics clearly breach their thresholds (real measured values, e.g. `~0.41-0.45s` latency against a `0.25s` threshold).
5. Rollouts marks the `AnalysisRun` `Failed`, aborts the rollout, scales the bad `ReplicaSet` back to **0**.
6. The stable `ReplicaSet` never dropped below 5/5 available the entire time.

To see the actual numbers behind the abort:
```bash
kubectl -n demo-app get analysisrun
kubectl -n demo-app describe analysisrun <name-from-above>
```

**Worth narrating if demoing live:** check `kubectl -n argocd get application demo-app -o jsonpath='{.status.resources}'` afterward. It'll still say `Synced`, not `OutOfSync` — Argo CD's self-heal only reverts drift on fields your manifests *declare*, and this patch added an `env` var the manifest never mentions at all. See README's Failure-Mode Walkthrough #3 for the full explanation; it's a more useful lesson than the "obvious" one.

---

## 9. Reset back to a clean baseline

Because of the self-heal blind spot above, the injected failure stays live until you remove it yourself:

```bash
kubectl -n demo-app patch rollout demo-app --type=json \
  -p='[{"op":"remove","path":"/spec/template/spec/containers/0/env"}]'
```

Confirm it settles back to `Healthy` at 5/5:
```bash
kubectl argo rollouts get rollout demo-app -n demo-app
```

---

## 10. Tear down

```bash
./scripts/teardown.sh
```
Deletes the whole kind cluster. Nothing here is stateful or worth preserving — rerunning this guide from step 2 reproduces everything from scratch.

---

## Troubleshooting

Real issues hit building and testing this repo — all already fixed in the committed manifests/scripts, listed here in case anything resurfaces (e.g. on a different Kubernetes/Argo CD version):

| Symptom | Cause | Fix (already in this repo) |
|---|---|---|
| `kubectl apply` fails with `metadata.annotations: Too long: must have at most 262144 bytes` | Argo CD's/Rollouts' largest CRDs overflow the client-side `last-applied-configuration` annotation limit | `bootstrap/01` and `02` use `kubectl apply --server-side --force-conflicts` |
| Rollouts install fails with `404 Not Found` on the release URL | GitHub releases use `/latest/download/`, not Argo CD's `stable`-branch convention | `bootstrap/02` uses `latest` |
| `bootstrap/04` fails with `unexpected EOF while looking for matching` | An apostrophe inside a `${VAR:?message}` broke bash's quote parsing even inside double quotes | Rephrased to avoid the apostrophe |
| `demo-app` pods stuck `ImagePullBackOff`/`ErrImagePull` even after `kind load docker-image` | `:latest` tag defaults to `imagePullPolicy: Always`, so kubelet ignores the locally-loaded image and tries Docker Hub | `imagePullPolicy: IfNotPresent` set explicitly in `rollout.yaml` |
| Every `AnalysisRun` errors with `no data returned from the metric provider` | No traffic hitting the app at all — `http_requests_total` has zero series | `load-generator` Deployment ships always-on in the base |
| Same "no data" error even with the load generator running | Prometheus never scraped `demo-app` — kube-prometheus-stack only auto-discovers `ServiceMonitor`s labeled `release: kube-prometheus-stack` | `servicemonitor.yaml` carries that label |
| `kubectl argo rollouts: command not found` in PowerShell, but works in Git Bash | `~\bin` is on Git Bash's PATH by convention, but not on the Windows user `PATH` that PowerShell/cmd use | Add it explicitly (see Prerequisites above); needs a **new** terminal window to take effect |
| `AnalysisRun` fails right after deleting/recreating a `Rollout`, even with traffic flowing | Cold-start: fresh pods need ~2 scrape intervals (30s) before `rate()` has enough samples — hitting the analysis step before that warms up looks identical to a real failure | Wait ~60s after any `Rollout` recreation before triggering analysis; not an issue in normal operation since the baseline stays warm |
