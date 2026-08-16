# KubeMD 发布帖文案（验证通过后直接用）

> 格式：Show HN / Reddit / 掘金 / V2EX
> 按渠道裁剪，别原样发全平台

---

## 英文 · Show HN（正式版）

**标题：** Show HN: KubeMD — evidence-first K8s diagnosis with case memory (DSH skill)

**正文：**

When your Kubernetes pod starts CrashLoopBackOff, the usual approach is to Google, try random fixes, and hope.

KubeMD takes a different approach: a structured, evidence-first diagnosis workflow that treats every failure like a clinical procedure — not guesswork.

**What it does:**
1. Builds a 10-second feedback loop (events + previous logs = deterministic red signal)
2. Collects signals in a strict order (events → status → logs → node)
3. Ranks 3-5 falsifiable hypotheses (each with a prediction, not vibes)
4. Fixes with dry-run semantics (`kubectl diff`, `rollout undo`)
5. Records the resolved diagnosis into a local case library

Next time the same symptom appears, it searches the case library first — a recalled past fix is the fastest diagnosis.

**How it works:**
- A DSH skill (`~/.dsh/skills/dsh-k8s-diagnosis/`): agent loads the 7-phase procedure + playbooks on demand (token-efficient progressive disclosure)
- A `go install`-able CLI: same deterministic rules, zero dependencies, no server needed
- Both share one core: the deterministic diagnosis engine from [aiops-platform](https://github.com/guiyi-labs/aiops-platform)

**Inspired by:** [KubeShark](https://github.com/LukasNiessen/kubernetes-skill) (manifest hallucination prevention, ★367) — but targeting *runtime diagnosis*, not writing YAML. Also influenced by [mattpocock's diagnosing-bugs](https://github.com/mattpocock/skills) (feedback loop methodology).

**Demo:** [CLI running on a real fault-injected kind cluster](https://github.com/guiyi-labs/kubemd/blob/main/assets/demo-cli.gif)

```bash
git clone https://github.com/guiyi-labs/kubemd ~/.dsh/skills/dsh-k8s-diagnosis
```

Would love feedback from anyone running K8s in production — especially: what failures eat the most of your time? I'll add playbooks for the most common ones.

---

## 英文 · Reddit（r/kubernetes + r/devops）

**标题：** KubeMD: evidence-first K8s diagnosis skill for DSH with case memory

**正文：**

Built a DSH skill that diagnoses live K8s failures (CrashLoop, OOM, NodeNotReady, NetworkPolicy deny, pending) using a clinical workflow:

1. Build a red-capable feedback loop (10s deterministic signal)
2. Collect signals in strict order (events → status → logs → node)
3. Rank falsifiable hypotheses
4. Fix with dry-run, record the case

Every resolved diagnosis becomes a searchable case entry. Next occurrence recalls the past fix instantly.

Also ships as a `go install` CLI with the same rules. Zero server, zero database.

**Repo:** https://github.com/guiyi-labs/kubemd

Feedback especially welcome from SREs: which failures eat most of your time? I'll add playbooks for the top ones.

---

## 中文 · 掘金 / V2EX

**标题：** KubeMD — K8s 急诊医生：证据优先的故障诊断 + 案例记忆

**正文：**

Pod CrashLoopBackOff、OOMKilled、NodeNotReady——你上一次排查 K8s 故障花了多久？

KubeMD 是一个 DSH (DeepSeek Harness) skill，把临床诊断的思路搬到 K8s 排障：

1. 先建 10 秒反馈环（events + previous logs = 确定性红信号）
2. 按顺序采集信号（不瞎猜，一次一个变量）
3. 排 3-5 个可证伪假设（每个假设带预测，不是直觉）
4. dry-run 语义修复（`kubectl diff`，`rollout undo`）
5. 把修复记录存入案例库——下次同样症状秒回

同时提供了 `go install` CLI（同一套规则，零依赖、无服务器）。

**仓库：** https://github.com/guiyi-labs/kubemd

---

## B 站（视频描述）

KubeMD —— K8s 急诊医生：一个给 DeepSeek Harness 用的故障诊断 skill，帮你用临床诊断的思路排查 K8s 故障（CrashLoop/OOM/NodeNotReady），并且把每次修复都记下来——下次同样问题秒回。

演示：aiops CLI 在真实故障集群上 15 秒定位根因（诊断 + 案例回忆）。

#Kubernetes #DevOps #AIOps #DeepSeekHarness #故障排查