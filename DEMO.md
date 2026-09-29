# Demo Script (~3 minutes)

Goal: in one continuous take, show a bad deploy getting caught and rolled back by an SLO gate, with zero manual intervention — then use the demo script's own imperative shortcut to show a real, non-obvious edge in how Argo CD's self-heal actually works. This is the single most convincing moment in the repo; everything else (README decision log, hardening section) is there for whoever wants to read further after watching this.

## Setup (before recording, not part of the 3 minutes)

- Cluster already bootstrapped and `demo-app` `Rollout` healthy at `v1`, `FAILURE_RATE=0.0`, 100% stable.
- Three panes visible on screen:
  1. **Terminal A** — `kubectl argo rollouts get rollout demo-app -n demo-app --watch` (the live rollout dashboard)
  2. **Terminal B** — free, for running commands
  3. **Browser** — Argo CD UI, `demo-app` Application tree view, zoomed in enough to read sync status
- Have `README.md`'s architecture diagram open in a fourth tab/pane, collapsed until needed.

## Script

**0:00–0:15 — Cold open**
> "This is a canary release pipeline for a Kubernetes service, running entirely GitOps-style through Argo CD — and it can catch and roll back a bad deploy on its own, with no one running `kubectl rollout undo`. Let me show you."

Show Terminal A: `Rollout` healthy, `v1`, `100%` stable. Show the Argo CD UI: green, `Synced`, `Healthy`.

**0:15–0:40 — Orient**
> "Quick architecture: Argo CD syncs this repo into the cluster — that's the App-of-Apps tree you're looking at. Argo Rollouts owns the actual canary — traffic shifts in steps, 20, 40, 100 percent. And at each step, it runs a live Prometheus query against a success-rate and latency SLO before it'll promote further."

Flash the Mermaid architecture diagram from the README for ~5 seconds — don't linger, it's context, not the point.

**0:40–1:05 — Trigger the bad deploy**
> "I'm going to ship a version with a 40% error rate — think a bad database migration, or a downstream dependency that just started timing out."

Terminal B:
```bash
./scripts/inject-failure.sh 0.4
```

> "That's a live patch rolling out a new revision right now."

**1:05–2:05 — Watch it get caught**

Cut to Terminal A. Narrate as it happens, don't rush this — it's the payoff:

- Canary steps to 20%. *"One out of five pods is now running the bad version."*
- `AnalysisRun` starts. *"Argo Rollouts just kicked off a Prometheus query — success rate and p99 latency, checked every 15 seconds."*
- Measurements start failing. *"There — it's already seeing the elevated error rate."*
- After ~3 failed checks: `AnalysisRun` → `Failed`, `Rollout` → `Degraded`. *"And that's it. It aborted the rollout and scaled the bad ReplicaSet back to zero. Nobody clicked anything."*

If there's time, briefly `kubectl describe analysisrun` in Terminal B to show the actual measurement values against the threshold — concrete numbers land better than a status word.

**2:05–2:40 — The edge case self-heal doesn't cover**

Cut to the Argo CD UI (or `kubectl -n argocd get application demo-app -o jsonpath='{.status.resources}'`).

> "Now — that patch I ran didn't go through git, so I'd expect Argo CD to flag it out-of-sync and self-heal it back. It doesn't. Watch: still says Synced."

> "Here's why, and it's worth knowing if you run Argo CD for real: `selfHeal` reverts fields your manifests actually *declare* when they drift from git. My patch *added* a field — an env var — that the manifest never mentions at all. There's nothing in git to compare it against, so Argo CD has no opinion on it and leaves it alone. Self-heal isn't a dragnet against every imperative change; it protects exactly what you've written down, nothing more."

**2:40–3:00 — Close**
> "So: a regression got caught by an SLO gate and rolled back automatically with zero manual steps — but the GitOps safety net underneath it has a real blind spot for changes it was never told to care about. Both of those are in the README's decision log and failure-mode walkthrough, along with what I'd lock down to close that gap for real. Link's below."

Cut.

## If something doesn't cooperate live

- **`AnalysisRun` takes longer than expected to fail:** narrate through it — "it's still collecting measurements, give it a few more seconds" — rather than jumping ahead. Dead air with an explanation reads better than a jump cut mid-mechanism.
- **Someone in the audience asks why Argo CD doesn't just revert *everything* imperative:** that's the whole point of the 2:05 beat — it only reverts drift on fields the manifest declares. If you want a harder guarantee than that, it has to come from policy (e.g. an admission controller rejecting undeclared fields), not from `selfHeal` alone — say so if it comes up.
- **Have a pre-recorded fallback clip of one full inject-failure → rollback cycle**, timestamped, in case a live take runs long or a component hiccups — swap it in during editing rather than re-recording the whole three minutes.
