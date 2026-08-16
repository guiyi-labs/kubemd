# KubeMD — Kubernetes 急诊医生

**证据优先的 Kubernetes 运行时故障诊断 —— 自带案例记忆。**

一个 DSH（DeepSeek Harness）skill，诊断的是**线上故障中的集群**，而不是编写 manifests。当 Pod 进入 CrashLoop、节点 NotReady、Service 停止响应时，KubeMD 按既定流程执行：捕获上下文 → 建立可复现的反馈环 → 采集信号 → 排序可证伪假设 → dry-run 修复 → **记录案例，下次秒回**。

> 与 KubeShark 类 skill 的区别：它们防止*编写 YAML 时*的幻觉；KubeMD 负责查明*正在运行的负载为什么坏了*——并且永远不会忘记修复方法。

[![powered by dsh](https://img.shields.io/badge/powered_by-dsh-4D6BFE?style=flat-square&logo=deepseek&logoColor=white)](https://github.com/deepseek-ai/deepseek-harness)
[![License](https://img.shields.io/badge/License-Apache%202.0-yellow.svg)](LICENSE)

## 安装（30 秒）

```bash
git clone https://github.com/guiyi-labs/kubemd ~/.dsh/skills/dsh-k8s-diagnosis
```

完成。DSH 会自动发现 `~/.dsh/skills/` 下的 skill，无需重启。

> DSH（DeepSeek Harness）—— 万物皆插件。Skill 是 agent 按需加载的指令包 + 脚本。

## 演示

CLI 在真实故障注入 kind 集群上运行（diagnose → 4 项发现 → 案例秒回）：

![KubeMD 演示 — aiops CLI 在真实故障集群上](assets/demo-cli.gif)

## 它做什么

```
症状: "pod CrashLoopBackOff after image update to :latest"
   │
   ├─ Phase 1  捕获上下文      （集群、范围、近期变更）
   ├─ Phase 2  建立反馈环      （kubectl events/日志 → 10 秒可红信号）
   ├─ Phase 3  采集信号        （事件 → 状态 → previous 日志 → 节点）
   ├─ Phase 4  排序 3-5 个可证伪假设（预测式，而非直觉）
   ├─ Phase 5  dry-run 验证    （kubectl diff / rollout undo）
   ├─ Phase 6  记录案例        （cases.yaml → 下次秒回）
   └─ Phase 7  输出契约        （ROOT_CAUSE / EVIDENCE / FIX / CASE_RECORDED）
```

## 包含内容

| 路径 | 用途 |
|---|---|
| `SKILL.md` | 7 阶段流程（精简、省 token） |
| `references/signal-map.md` | 症状 → 信号 → 命令 速查表 |
| `references/playbooks/` | 深度排障手册：crashloop / oom / network / pending / node-not-ready（已在真实 kind 集群验证） |
| `scripts/collect-signals.sh` | Phase 3 一键信号采集 |
| `scripts/record-case.sh` | 将已解案例追加进 `cases.yaml` |
| `cases.yaml` | 不断增长的案例库（含示例，随你的实战增长） |
| `verification-report.md` | 真实故障注入验证报告（5 场景、无硬错误） |

## 案例记忆（差异化核心）

每条已解诊断都会成为一条记录。下次相同症状出现时，先检索：

```bash
grep -i "crashloop" ~/.dsh/skills/dsh-k8s-diagnosis/cases.yaml
```

一条被回忆起的旧案例是最快的诊断：复现环 + 记住的修复 + 重新验证。这是更大 AIOps 知识闭环的本地 MVP——"把已解诊断蒸馏进可检索库"的思想，同样驱动着平台级 LLM 辅助根因分析。

## 也提供：aiops CLI

更喜欢终端？同一套确定性诊断规则以 `go install` CLI 发布：

```bash
go install github.com/guiyi-labs/aiops-platform/cmd/aiops@latest
aiops diagnose --namespace demo --pod web-0     # 基于规则的根因
aiops cases --query "crashloop"                 # 历史案例秒回
```

无服务器、无数据库、单二进制。同一引擎两个入口：KubeMD（agent 引导）↔ aiops CLI（终端自动化）。

## 设计原则（取各家之长）

- **反馈环优先**（mattpocock/diagnosing-bugs）：反馈环存在之前不立假设
- **省 token 渐进式披露**（KubeShark）：SKILL.md 保持精简，排障手册按需加载
- **真实可信**：每一步标注"已验证/未验证"；不运行过的不宣称
- **dry-run 语义**：`kubectl diff` 先于 apply，`rollout undo` 优于线上手改

## 路线图

- [x] SKILL.md + signal-map + 5 playbooks + scripts
- [x] cases.yaml 示例 + LICENSE + 品牌化
- [x] 真实 kind 集群验证（fault injection：crashloop / oom / netpol deny）
- [ ] MCP tooling for DSH diagnosis hints
- [ ] cases.yaml ↔ aiops-platform 知识库（RAG）同步

## 许可

Apache-2.0
