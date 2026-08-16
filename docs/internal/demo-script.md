# 演示 GIF 剧本（90 秒）— CLI + skill 双场景

> 用途：star 转化的核心素材。录制方：指挥中枢。
> 目标观众：陌生工程师。3 秒看懂"这工具干什么"，30 秒看到"排障真有用"。
> 要求：真实运行画面（非截图拼接）；终端大字体；无敏感信息。

## 场景 A：CLI 直出（0-50s，主场景，终端录制）

```
[0-5s]   进入终端，光标闪烁 → 一行命令：
         $ go install github.com/guiyi-labs/aiops-platform/cmd/aiops@latest
[5-8s]   （切到 kind/k3s 环境提示，或直接演示 demo 模式）
         $ aiops diagnose --namespace demo --pod web-0
[8-40s]  输出滚动：确定性规则逐条核对
         ├─ rule: pod_restart_loop        → 命中 (restartCount=14)
         ├─ rule: image_tag_drift         → 命中 (:latest unpinned)
         ├─ rule: config_mount_missing    → 命中 (volume not found)
         └─ ROOT_CAUSE: unpinned :latest + missing config volume
[40-50s]  $ aiops cases --query "crashloop"
          返回历史案例（同症状 → 上次修复：pin digest + config volume）
          打字一行： "diagnosed + recalled in seconds."
```

## 场景 B：skill 引导（50-90s，DSH 会话内录制，可选）

```
[50-60s]  DSH 会话界面：用户输入 "pod web-0 is crash-looping, diagnose it"
[60-75s]  Agent 装载 skill（终端可见 SKILL.md 被读取/或直接展示流程）
          kubectl get events → --previous logs → 排障树 → 假设排序
[75-90s]  ROOT_CAUSE 一行输出 + cases.yaml 追加记录（record-case.sh）
          结尾定格: "KubeMD — the surge doctor. Diagnoses once, remembers forever."
```

## 录制提示

| 项 | 要求 |
|---|---|
| 字体 | 终端 ≥16pt，高对比配色（深底浅字） |
| 时长 | 总 ≤90s；场景 A ≥60%（star 转化浓度最高） |
| 画面节奏 | 每 5-10s 一个视觉变化（命令滚动、结果高亮） |
| 高亮 | 关键行（ROOT_CAUSE / recalled）用不同颜色或粗体 |
| 结尾 | 最后 5s 定格品牌句，露出 KubeMD 名 |
| 真实 | 所有命令真实执行输出；demo 模式可接受的用 demo 数据但标注 |

## 降级方案（若 CLI 环境未就绪）

场景 A 可用 skill 的 `collect-signals.sh` 替代：

```
$ ./collect-signals.sh demo web-0
[1/6] pod 概览 → [2/6] 重启 → [3/6] 事件 → [4/6] --previous → 根因
```

一样的叙事（信号采集 → 根因 → 案例），没有 CLI 也能录。

## 产出物

- `demo-cli.gif`（场景 A，主推）
- `demo-skill.mp4`（场景 B，可选，B 站用）
- README 嵌入 gif + 发布帖复用