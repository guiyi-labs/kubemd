# CrashLoopBackOff 排障 Playbook

> 加载条件：`restartCount > 0` 或事件含 `BackOff`。
> 适用失败模式：应用启动崩溃 / 探针误杀 / 配置缺失 / OOM / 镜像问题。

## 故障树（按概率排序的假设）

```
CrashLoopBackOff
├── 1. 应用启动即崩（最常见）
│     └── 证据: kubectl logs --previous 有应用报错/panic
│     └── 常见因: 缺配置/Secret、依赖服务未就绪、数据库连接失败、镜像 :latest 漂移
├── 2. 启动后被探针杀死
│     └── 证据: --previous 日志正常结束（无报错），事件有 Unhealthy/Liveness probe failed
│     └── 常见因: 探针 initialDelay 太短、timeout 太短、健康检查路径/端口错
├── 3. OOMKilled
│     └── 证据: lastState.terminated.reason == OOMKilled，kubectl top 用量逼近 limit
│     └── 常见因: limit 设置过低、内存泄漏、无 limit 反被 node 压力波及
├── 4. 镜像层问题
│     └── 证据: 事件 ErrImagePull/ImagePullBackOff（不会 CrashLoop 但常被误解为）
│     └── 常见因: tag 不存在、私有仓库认证、架构不匹配
└── 5. 命令/参数错误
      └── 证据: --previous 日志显示 entrypoint 找不到命令
      └── 常见因: args 拼写、镜像入口变更

```

## 标准操作顺序（Phase 2-5 落地）

```bash
# 1. 反馈环（能红）——重放给用户的症状
kubectl get events --sort-by=.lastTimestamp -n <ns> | tail -20
kubectl get pod <pod> -n <ns> -o wide

# 2. 拿到"真声"
kubectl logs <pod> --previous -n <ns> --tail=200
#   ⚠️ previous 日志可能被 CRI 时序清理而取不到（含真实崩溃场景）。
#   兜底：改用当前实例最后输出，两者结合看
kubectl logs <pod> -n <ns> --tail=200

# 3. 区分 1 vs 2（应用崩 vs 探针杀）
kubectl get pod <pod> -n <ns> -o jsonpath='{range .status.containerStatuses[*]}{.name}: restarts={.restartCount} lastReason={.lastState.terminated.reason} exit={.lastState.terminated.exitCode}{"\n"}{end}'

# 4. 按故障树选假设 → 单变量验证
#    假设1: 修配置
#    假设2: 调探针
#    假设3: 调 limit（或查泄漏）
```

## 验证每个假设的"预测"

| 假设 | 改变 | 预测现象 |
|---|---|---|
| 配置缺失 | 挂载 Secret/ConfigMap | restartCount 停止增长 |
| 探针太快 | initialDelaySeconds 调大 | Pod 变 Ready，不再重启 |
| limit 过小 | 调高 memory limit | OOMKilled 消失 |
| 镜像漂移 | 固定 digest | 启动正常 |

一次只改一个❗改完重跑反馈环（Phase 2 的命令）确认变绿。

## 快速修复路径（dry-run 语义）

```bash
# 回滚优先于手改（如果是对刚发布的改动）
kubectl rollout undo deployment/<name> -n <ns>
# 或先看差异
kubectl diff -f <manifest> 
# 修复后确认
kubectl rollout status deployment/<name> -n <ns> --timeout=120s
```

## 收尾（Phase 6-7）

- 确认：restartCount 不再增长 + 事件停止 BackOff + `kubectl get pod` Ready
- 记录 case 到 `cases.yaml`（symptom/signals/root_cause/fix/verification/tags）
- 下次同症状 → 先 grep cases.yaml，可能直接命中