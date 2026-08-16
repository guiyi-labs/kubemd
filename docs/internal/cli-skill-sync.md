# CLI ↔ Skill 协同说明（dsh-k8s-diagnosis × cmd/aiops）

> 两条线共享同一内核（确定性规则诊断 + 案例回忆），面向不同用户入口。
> 更新时间：2026-08-16（CLI `96c7856` 已完成；skill 验证进行中）

## 两条线是什么

| | cmd/aiops（CLI） | dsh-k8s-diagnosis（skill） |
|---|---|---|
| 形态 | Go 二进制，`go install` 一行装 | `~/.dsh/skills/` 拷入即用（SKILL.md + 脚本） |
| 用户 | 终端用户 / 脚本化（-o json） | DSH/agent 会话内的排障引导 |
| 内核 | aiops 确定性诊断规则（internal/diagnosis 纯函数） | 7 阶段流程 + 5 playbook + signal-map |
| 案例 | `aiops cases` 查历史库（无 server 降级规则目录） | cases.yaml + grep 秒回 |
| 依赖 | 零（无 server/DB，无 kubeconfig 走 demo） | 零（纯文本 + shell） |
| 状态 | ✅ 已完成 v0.1.0 | 🔄 验证中 |

## 协同关系

```
        确定性诊断内核（aiops internal/diagnosis）
                │
      ┌─────────┴─────────┐
      ▼                   ▼
  cmd/aiops CLI      dsh-k8s-diagnosis skill
  （终端/脚本入口）    （agent 排障引导入口）
      │                   │
      └──── 案例回忆 ─────┘
      aiops cases      cases.yaml grep
```

**同一个故事，两个入口**：
- 面试/毕设讲 aiops：确定性规则 + RAG 案例库（P1）
- 对外讲 skill：agent 排障时也引用历史案例（与 aiops 同源的本地 MVP）
- 对外讲 CLI：`go install` 一行装，无依赖体验确定性诊断

## 对外叙事（README 可用）

- CLI："No server. No database. K8s diagnosis with case memory in one binary."
- Skill："The diagnosis workflow your agent runs when the cluster is on fire — with a memory of past fixes."

## 当前状态

- [x] aiops CLI diagnose+cases（`96c7856`，899 行，含测试）
- [x] aiops v0.1.0 release readiness（`d88144e`）
- [x] dsh-k8s-diagnosis 完整打包（14 文件，含 LICENSE/.gitignore/cases.yaml 示例）
- [ ] skill 命令真实验证（aiops Agent 进行中）
- [ ] 独立仓库发布（guiyi-labs/dsh-k8s-diagnosis）

## 发布后可选联动

- skill 的 cases.yaml ↔ CLI 的 `aiops cases` 数据互通（一个导出脚本即可）
- README 互相引用（skill 提 CLI 做自动化入口，CLI 提 skill 做 agent 引导）