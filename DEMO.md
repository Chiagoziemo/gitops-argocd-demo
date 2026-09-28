# Demo Script (~3 minutes)

Goal: in one continuous take, show a bad deploy getting caught and rolled back by an SLO gate, with zero manual intervention — and show Argo CD's GitOps self-heal fighting the demo's own shortcut in the background. This is the single most convincing moment in the repo; everything else (README decision log, hardening section) is there for whoever wants to read further after watching this.

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

**2:05–2:40 — The second safety net**

Cut to the Argo CD UI (or `kubectl -n argocd get application demo-app`).

> "One more thing — that patch I ran a minute ago didn't go through git. Argo CD noticed the live cluster drifted from what's committed, flagged it out-of-sync, and it's about to self-heal it back — independent of the rollback that just happened. In a real environment, that's what stops anyone from quietly kubectl-patching around the process."

Show the sync status flip `OutOfSync` → `Synced`.

**2:40–3:00 — Close**
> "So: a regression got caught by an SLO gate, rolled back automatically, and the cluster healed itself back to what's in git — all from one bad deploy, zero manual steps. The repo has a full decision log and a production-hardening section if you want to see what I'd change to run this for real — README's linked below."

Cut.

## If something doesn't cooperate live

- **`AnalysisRun` takes longer than expected to fail:** narrate through it — "it's still collecting measurements, give it a few more seconds" — rather than jumping ahead. Dead air with an explanation reads better than a jump cut mid-mechanism.
- **Argo CD self-heals before the `AnalysisRun` finishes:** that's fine, actually — call it out live: "self-heal already reverted the env vars, and the rollout's converging on its own too — belt and suspenders." Don't treat it as something going wrong.
- **Have a pre-recorded fallback clip of one full inject-failure → rollback cycle**, timestamped, in case a live take runs long or a component hiccups — swap it in during editing rather than re-recording the whole three minutes.
