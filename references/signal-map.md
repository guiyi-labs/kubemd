# dsh-k8s-diagnosis — 信号速查表（Signal Map）

> 用途：Phase 3 按信号采集时查表。每个症状 → 采集命令 → 该信号能排除/确认什么。
> 加载策略：只在 Phase 3 遇到表内症状时加载，避免烧 token。

## 症状 → 信号 → 命令

| 症状 | 第一信号 | 命令 | 该信号回答的问题 |
|---|---|---|---|
| CrashLoopBackOff | 容器重启原因 | `kubectl logs <pod> --previous -n <ns> --tail=200` | 是应用自己崩的，还是被探针杀？ |
| | 事件 | `kubectl describe pod <pod> -n <ns>` (Events: BackOff/Unhealthy) | 重启是 OOM 还是探针失败还是 image 拉取？ |
| OOMKilled | 容器状态 | `kubectl get pod -o jsonpath='{.status.containerStatuses[0].lastState}'` | terminated.reason == OOMKilled? |
| | 用量趋势 | `kubectl top pod <pod> -n <ns>` | 用量逼近 limit？还是 limit 本身设置过低？ |
| ImagePullBackOff | 事件 | `kubectl get events -n <ns> --sort-by=.lastTimestamp` | ErrImagePull 原因：tag 不存在/认证失败/架构不符/网络？ |
| Pending | 调度事件 | `kubectl describe pod <pod> | grep -A5 Events` | FailedScheduling 具体原因？（cpu/mem/taint/selector/PVC） |
| | PVC | `kubectl get pvc -n <ns>` | 是否 Bound？storageClass 存在？ |
| NodeNotReady | 节点状态 | `kubectl describe node <node>` | 条件：MemoryPressure/DiskPressure/PIDPressure/Ready=False 原因 |
| Service 不通 | Endpoints | `kubectl get endpoints <svc> -n <ns>` | endpoints 是否为空？（selector 失配） |
| | DNS | `kubectl run dns-test --rm -it --image=busybox -- nslookup <svc>.<ns>` | CoreDNS 解析？ |
| | 网络策略 | `kubectl get netpol -n <ns>` | 是否误拦？ |
| HPA 不扩 | HPA 状态 | `kubectl get hpa <name> -o yaml` | metrics 是否上报？target 是否过小？Pod 是否 Ready？ |
| 慢/超时 | 探针 | `kubectl describe pod | grep -A2 Liveness/Readiness` | 探针阈值 vs 实际启动时间（delay 不够？） |
| | 资源争抢 | `kubectl top node && kubectl top pod -A` | 节点整体压力？ |

## 信号优先级规则

1. **Events 永远第一个看**——它讲"故事"（为什么调度/为什么重启/为什么拉不到镜像），比状态字段好懂
2. **`--previous` 日志是崩溃循环的"真声"**——当前日志只在容器还活着时有用，崩溃的要看上一轮
3. **restartCount 是客观数字**——先看它再猜原因：0 = 未重启过（问题在启动前/调度前），大数字 = 循环崩溃
4. **一个信号只回答一个问题**——不要一次采集十个再猜，每次采集后都要能"确认或排除"一个假设

## 输出习惯

- 采集结果用 `ROOT_CAUSE:` 一行结尾（见 SKILL.md Phase 7）
- 每次都把 `cases.yaml` 里同症状的历史案例先查一遍（10 秒，可能直接命中）