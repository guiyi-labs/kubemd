---
name: dsh-k8s-diagnosis
description: "Diagnose live Kubernetes failures (CrashLoopBackOff, OOMKilled, NodeNotReady, ImagePullBackOff, Network/CNI failures, HPA starvation, DNS failures, pending pods) with an evidence-first procedure: capture context, collect signals (events/status/logs), rank falsifiable hypotheses, verify one variable at a time, fix with dry-run semantics, and record the resolved diagnosis into a reusable case library. Use when the user reports a broken/unhealthy/failing/slow pod, deployment, node, service, or cluster, or asks to diagnose/debug/triage a Kubernetes issue."
---

# K8s Runtime Diagnosis (dsh-k8s-diagnosis)

Evidence-first runtime diagnosis for Kubernetes failures. Different from writing manifests: this skill works on **live clusters with broken workloads**. Skip a phase only when explicitly justified.

## Core contract

Every diagnosis ends with one of:
1. A **root cause** + evidence timestamp line, and
2. A **case entry** distilled for future recalls.

Record every verified step. Redact secrets first (write `<REDACTED>`; build against env vars). If redaction loses the signal, say so.

## Phase 1 — Capture execution context (30s)

Before touching the cluster, record:
- Cluster version / distribution: `kubectl version --short`, context name
- Scope: namespace, workload type (Deployment/StatefulSet/DaemonSet/Job)
- What the user sees: error message, symptom, timing (when did it start?)
- Recent changes: deploys, configmaps, image tags, node operations (ask / check history)

If unknown, state assumptions explicitly.

## Phase 2 — Build a feedback loop (the skill)

**This is the skill.** Everything else is mechanical. A **tight, red-capable signal** for a K8s failure is:

```bash
# The canonical loop: fail must reproduce within seconds, deterministically
kubectl get events --sort-by=.lastTimestamp -n <ns> | tail -20    # red on new events
kubectl describe pod <pod> -n <ns>                                # red on condition changes
kubectl logs <pod> --previous -n <ns> --tail=200                  # red on error lines
```

A loop is ready when: it goes red on **this** symptom, is deterministic, fast (<10s), and you can run it unattended. If the symptom is flaky (1% repro), raise reproduction rate first (restart, stress, narrow window) — a 50% bug is debuggable, 1% is not.

**Do not form a theory before the loop exists.** No red loop, no hypothesis.

## Phase 3 — Collect signals in order

Read in this order, one at a time, until the feedback loop's red signal is explained:

1. **Pod status**: `kubectl get pod <pod> -o wide -n <ns>` — phase, restarts, node, IP
2. **Events** (the story): `kubectl describe pod <pod>` Events section — FailedScheduling, BackOff, OOMKilling, Unhealthy, image pull errors
3. **Container state & probes**: `kubectl get pod <pod> -o jsonpath='{.status.containerStatuses}'` — waiting reason, lastState, restartCount, probe failures
4. **Logs**: `kubectl logs <pod> --previous -n <ns> --tail=200` — the app's own error (crash loop's real voice is in --previous)
5. **Node context**: `kubectl describe node <node>` — pressure conditions, allocatable vs requested
6. **Workload config**: recent rollout, resource requests/limits, probe config, image tag (mutable vs pinned)

Map each signal to a hypothesis. Change one variable at a time.

## Phase 4 — Rank falsifiable hypotheses (3-5)

Generate 3-5 ranked hypotheses **before** testing any. Each must state a prediction:

> "If <X> is the cause, then <changing Y> will make the symptom disappear / worsen."

Common K8s failure hypotheses to check against:
- CrashLoopBackOff: app crash on startup (check `--previous` logs) vs probe/kill (check restartCount + events) vs missing config/secret
- OOMKilled: memory limit too low vs leak (check `kubectl top pod`, limit vs usage trend) vs node memory pressure
- ImagePullBackOff: wrong tag/registry auth vs arch mismatch (check events; manifest list supports node arch?)
- Pending: insufficient resources vs nodeSelector/toleration mismatch vs PVC not bound vs topology spread unschedulable
- Network failure: CNI broken vs Service selector mismatch vs NetworkPolicy deny vs DNS (check `kubectl get endpoints`, coredns pods, cluster policy)
- HPA starvation: metrics unavailable vs target too low vs pod not ready (check `kubectl get hpa -o yaml`, metric server)

Show the ranked list to the user before testing. A 10-second checkpoint often re-ranks instantly ("we just changed X").

## Phase 5 — Verify with dry-run semantics

For every fix:
- Prefer `kubectl diff` over `kubectl apply` (see what changes)
- Prefer rollback: `kubectl rollout undo deployment/<name>` over editing live state
- Never delete user data without backup confirmation
- Only after root cause confirmed — a fix without a root cause is a flail

Each probe maps to exactly one Phase-4 hypothesis. Tag debug logs with a unique prefix (`[DBG-a4f2]`) for single-grep cleanup.

## Phase 6 — Record the case (differentiating feature)

Once resolved, distill a **case entry** — this is what makes this skill different from KubeShark and every generic debugging skill:

```yaml
case:
  symptom: "pod CrashLoopBackOff after image update to :latest"
  signals: ["restartCount 12", "previous log: panic: config missing", "events: BackOff"]
  root_cause: "unpinned :latest tag pulled breaking change; config not mounted"
  fix: "pin image digest + add config volume; rollout undo; verify"
  verification: "restartCount stops; readiness Ready; 10-min stable"
  tags: [crashloop, image-tag, config]
```

Where to store:
- Local MVP: append to `~/.dsh/skills/dsh-k8s-diagnosis/cases.yaml`
- With aiops-platform: the diagnosis engine auto-distills resolved records into its knowledge base (RAG) — historical case recall is provided with citations

Next occurrence of a similar symptom → search cases first:

```bash
grep -i "crashloop" ~/.dsh/skills/dsh-k8s-diagnosis/cases.yaml
```

A recalled past case is the fastest diagnosis: reproduction loop + recalled fix + re-verify.

## Phase 7 — Output contract

End with (redacted, machine-friendly):

```
ROOT_CAUSE: <one line, evidence-backed>
EVIDENCE: <timestamped signal that proves it>
FIX: <what changed>
VERIFY: <how re-run proved fix>
CASE_RECORDED: <path or "skipped — reason">
```

## Reference loading strategy (token-efficient, KubeShark pattern)

Load only what the phase needs:
- Signal cheatsheet: `references/signal-map.md` — symptom → signal → command mapping
- Common failure playbooks: `references/playbooks/crashloop.md`, `references/playbooks/oom.md`, `references/playbooks/network.md`, `references/playbooks/pending.md` (load on demand, not upfront)
- Case library: `cases.yaml` — grows with your own experiences (the moat)

Keep SKILL.md itself short (like KubeShark's ~100 lines). All depth lives in references.