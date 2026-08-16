# 第二 skill 方向储备（KubeMD 之后）

> 状态：储备设计，KubeMD 验证+发布后再评估启动。
> 原则：优先复用 aiops/netcheck/bootstrap 已有内核，不造无源之木。

## 候选 A：skill 生命周期管理 skill（DSH 生态空白位）

- 方向：`dsh-skill-doctor` —— 审计已安装 skills 的格式/安全/更新状态
- 依据：OpenClaw 生态 arc-*（lifecycle/security-audit/gitops）是明显刚需（393 个 DevOps skills 里 5+ 个）；DSH 生态无竞品
- 内核来源：netcheck 的安全基线思想 + aiops 的审计纪律
- 卖点：`SKILL.md` 格式契约校验 + frontmatter 检查 + 脚本安全检查
- 难度：中（纯文本校验 + shell），不依赖集群验证

## 候选 B：集群交付验收 skill（贴合 bootstrap）

- 方向：`dsh-cluster-acceptance` —— 交付后自动验收（节点 Ready/组件健康/冒烟/best-practice 检查）
- 依据：bootstrap 有完整双架构交付验收实践（Day2 套件），直接可提炼
- 卖点：从"装完就算完"到"可审计交付"——生产交付的 checklist 场景
- 难度：低-中（复用 bootstrap inventory/playbook 逻辑）

## 候选 C：网络巡检 skill（贴合 netcheck）

- 方向：`dsh-network-inspection` —— 资产发现/Ping/端口/HTTP/DNS 巡检闭环
- 依据：netcheck 有完整巡检链路 + 故障注入演示环境
- 卖点：网络工程专业对口；netcheck 已冻结，skill 是它的"轻量延续出口"
- 难度：中（需统一到 DSH skill 契约）

## 评估表

| 候选 | 复用内核 | DSH空白 | 竞争 | 难度 | star 预期 |
|---|---|---|---|---|---|
| A skill-doctor | netcheck 安全思想 | ✅ | 低 | 中 | 中 |
| B cluster-acceptance | bootstrap Day2 | ✅ | 低 | 低-中 | 中 |
| C network-inspection | netcheck 巡检 | ✅ | 低 | 中 | 中-高（网络受众稳定）|

## 建议

- **KubeMD 验证 + 发布稳定后**，优先 **候选 B（cluster-acceptance）**——成本最低、内核最现成、与 KubeMD 形成"交付+诊断"双 skill 矩阵
- 候选 C 留给网络工程叙事更多投入时（毕设答辩后）
- 候选 A 等 DSH 生态有 marketplace/规范信号再动（避免过于早期）