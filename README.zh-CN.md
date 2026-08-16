# dsh-k8s-diagnosis — 仓库布局说明

> 本目录结构对标 KubeShark（SKILL.md 精简 + 按需加载 references），
> 但领域不同：**它是"写 manifests 防幻觉"，我们是"运行时故障定位 + 案例沉淀"**。

## 目录结构

```
dsh-k8s-diagnosis/
├── SKILL.md                  # 7 阶段流程（反馈环优先 + 证据驱动）——主入口，~120 行
├── references/
│   ├── signal-map.md         # 症状→信号→命令 速查表（Phase 3 用，按需加载）
│   └── playbooks/
│       ├── crashloop.md      # CrashLoopBackOff 故障树 + 标准操作（已完成）
│       ├── oom.md            # OOMKilled     （待写）
│       ├── network.md        # Service/DNS/NetPol不通 （待写）
│       ├── pending.md        # Pod Pending 调度失败 （待写）
│       └── node-not-ready.md # 节点异常      （待写）
├── cases.yaml                # 案例库（诊断完成后追加，本地 MVP 形态）
└── scripts/
    ├── collect-signals.sh    # 一键采集 Phase 3 全部信号（待写）
    └── record-case.sh        # 追加案例到 cases.yaml（待写）
```

## 与 KubeShark 的差异化对照

| 维度 | KubeShark | dsh-k8s-diagnosis |
|---|---|---|
| 领域 | 生成/审查 manifests（创作侧） | 运行时故障定位（急诊侧） |
| 核心 | 反幻觉参考（好/坏示例） | 反馈环 + 证据时间戳 + 假设排序 |
| 记忆 | 无 | **案例库沉淀，同症状秒回**（= aiops RAG 的本地 MVP） |
| 输出 | 安全 manifests | ROOT_CAUSE + EVIDENCE + FIX + CASE |
| 分发 | Claude/Codex | DSH ecosystem（`~/.dsh/skills/`） |

## 与 aiops-platform 的对接（毕设主线联动）

- **现在（本地 MVP）**：cases.yaml 追加式记录，grep 召回
- **之后（对接 aiops）**：诊断引擎自动蒸馏 resolved 案例 → RAG 知识库 → 带引用的历史案例召回（这就是 aiops P1 的 skill 形态呈现）

## 交付状态

- [x] SKILL.md（7 Phase 主线）
- [x] references/signal-map.md
- [x] references/playbooks/crashloop.md
- [ ] playbooks: oom / network / pending / node-not-ready
- [ ] scripts/: collect-signals.sh / record-case.sh
- [ ] README.md（仓库门面，英文，安装即用 + badge）
- [ ] cases.yaml 初始示例（2-3 条真实案例）