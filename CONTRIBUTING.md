# Contributing to KubeMD

Thanks for helping make KubeMD better — every case record, playbook, and fix makes the next diagnosis faster.

## How you can help

### 1. Report a failure mode you hit (most valuable)

Hit a crash loop, an OOM, a network policy mystery, a node problem we don't cover?

- Open an issue with: symptom, signals you collected (`kubectl describe`, `events`, logs), and what fixed it (if anything).
- If a similar case already exists in `cases.yaml`, add your signals to the issue instead of duplicating.

### 2. Add a verified case

After you resolve a diagnosis, add the record to `cases.yaml`:

```bash
bash scripts/record-case.sh
```

…or hand-write an entry following the existing schema (`symptom`, `signals`, `root_cause`, `fix`, `verification`, `tags`).

> **Honesty rule**: mark `verification: VERIFIED` only if you actually reproduced the scenario. Unverified entries go as `demo`/`community (unverified in our env)` — never guess.

### 3. Contribute a playbook

Playbooks live in `references/playbooks/`. A good playbook covers one failure mode:

1. The symptom and how to confirm it
2. A minimal reproduction (image + deployment + expects)
3. The signal chain: which `kubectl`/`logs` commands prove each hypothesis
4. The fix with dry-run semantics first (`kubectl diff`, `rollout undo`)
5. What this playbook has NOT verified (honesty section)

### 4. Fix docs / bugs

Small fixes (typos, broken links, outdated commands) are very welcome as direct PRs.

## Getting set up

```bash
git clone https://github.com/guiyi-labs/kubemd
# install the skill
mkdir -p ~/.dsh/skills
ln -s "$(pwd)" ~/.dsh/skills/dsh-k8s-diagnosis
# or: cp -r . ~/.dsh/skills/dsh-k8s-diagnosis
```

## Style & standards

- `SKILL.md` stays lean (token budget) — deep material goes in `references/`.
- Frontmatter: `name` (kebab-case) + `description` required; follow dsh-skill-filesystem rules.
- Evidence over assertion: quote the actual signal, never "should be".
- Dry-run before apply; `rollout undo` over hand-editing live clusters.

## Proof of "verified"

We verify against a real fault-injected kind cluster (see `verification-report.md`, 5 scenarios, no hard errors). If you reproduce a scenario, add your environment (kind version, containerd, k8s version) to the report or to the case entry — platform quirks are valuable data (e.g. OOMKilling events absent on kind/containerd v2).

## License

By contributing you agree your changes are licensed under Apache-2.0 (the project license).