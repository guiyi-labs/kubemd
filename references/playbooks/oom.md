# OOMKilled 排障 Playbook

> 加载条件：`lastState.terminated.reason == OOMKilled` 或事件含 `OOMKilling`。
> 适用失败模式：容器内存越限被杀 / 节点内存压力回收 / 泄漏。

## 第一步：确认真的是 OOM（别和探针杀混淆）

```bash
kubectl get pod <pod> -n <ns> -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}'
# 期望: OOMKilled
kubectl get events -n <ns> --sort-by=.lastTimestamp | tail -10
# ⚠️ OOMKilling 事件因平台/CRI 而异（kind+containerd v2 实测不出现，只有 BackOff）。
#    以 lastState.terminated.reason==OOMKilled + exit 137 为准；BackOff 只表明重启循环，非 OOM 直接证据
```

> 陷阱：`exit code 137` ≠ 一定是 OOM（SIGKILL 也可能来自探针超时/手动 kill）。**以 reason 字段和 OOMKilling 事件为准**，不要只凭 exit code。

## 故障树

```
OOMKilled
├── 1. 内存 limit 设置过低（最常见）
│     └── 证据: kubectl top pod 显示 usage 稳定贴近 limit，restart 循环
├── 2. 应用内存泄漏
│     └── 证据: usage 随时间单边上涨 → 崩溃 → 回落 → 再涨
├── 3. 节点内存压力（不是 limit 问题）
│     └── 证据: 节点 MemoryPressure，多个 pod 被杀，limit 未到
├── 4. JVM/GC 类应用堆外内存
│     └── 证据: -Xmx 看着合理但 native/metaspace 超了
└── 5. 无 limit 但被 node 回收
      └── 证据: QoS=BestEffort（无 requests/limits），node 压力时先杀它
```

## 量化测量（Phase 3 信号，一次一个）

```bash
# 当前实时用量 vs limit
# ⚠️ kubectl top 依赖 metrics-server；kind 默认未装 → "Metrics API not
#    available"。未装时：① 用下方 resources jsonpath 确认 limit；② 参考
#    collect-signals.sh [5/6] 降级信号。安装（kind 需 --kubelet-insecure-tls）：
#    kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl top pod <pod> -n <ns>

# limit 配置
kubectl get pod <pod> -n <ns> -o jsonpath='{range .spec.containers[*]}{.name}: req={.resources.requests} lim={.resources.limits}{"\n"}{end}'

# 节点整体压力（判断是不是 node 问题）
kubectl top node
kubectl describe node <node> | grep -A5 "Conditions"
```

## 标准操作顺序

```bash
# 反馈环（能红）
kubectl get pod <pod> -n <ns> -o jsonpath='{.status.containerStatuses[0].restartCount}'
# 每次重启后立刻确认: kubectl top pod 用量曲线

# 判断假设：
# 假设1/5（limit/node）→ 看 QoS + 节点条件
# 假设2（泄漏）→ 看多次重启间的 usage 是否单调上涨
# 假设4（JVM）→ 进容器看 /proc/<pid>/status VmRSS 对比 -Xmx
```

## 修复路径（dry-run 语义）

| 假设 | 修复 | 验证预测 |
|---|---|---|
| limit 过低 | 调高 memory limit（如 512Mi→1Gi） | 重启停止、usage < limit 且留余地 |
| 泄漏 | 查 GC/连接池（日志 + heap dump）；短期先调高 limit 止血 | usage 不再单边涨 |
| 节点压力 | 移走负载 / 加节点 / 调低其他 pod；或给本 pod 加 QoS Guaranteed | node 条件恢复，pod 稳定 |
| JVM 堆外 | 调 `-XX:MaxMetaspaceSize` / `-XX:MaxDirectMemorySize` | 崩溃点消失 |

**验证**：修后观察 ≥10 分钟，restartCount 不增 + usage 有安全余量（<80% limit）。

## 收尾

- 确认：`lastState` 不再出现 OOMKilled、usage 曲线健康
- case 记录：`cases.yaml`（symptom=OOMKilled, tags: [oom, memory-limit, leak]）
- 对 aiops 的诊断规则来说，这条 → 「memory 信号 + 事件 OOMKilling → 根因=limit/泄漏」