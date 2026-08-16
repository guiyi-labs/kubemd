# Pod Pending 排障 Playbook（调度失败）

> 加载条件：`kubectl get pod` 显示 `Pending`，事件无 CrashLoop（还没起来）。
> 适用失败模式：资源不足 / 污点容忍 / nodeSelector / PVC / 调度器问题。

## 第一步：看调度事件（Pending 的"病历"都在这里）

```bash
kubectl describe pod <pod> | grep -A10 "Events:"
# FailedScheduling 里写了原因，直接读它比猜快
```

## 故障树（按事件文本归类）

```
Pending
├── 1. 资源不足
│     └── 事件: 0/2 nodes are available: insufficient cpu/memory
├── 2. 节点污点未容忍
│     └── 事件: 0/2 nodes are available: 2 node(s) had untolerated taint {key=...}
├── 3. nodeSelector / 亲和不匹配
│     └── 事件: node(s) didn't match node selector
├── 4. PVC 未绑定
│     └── 事件: pod has unbound immediate PersistentVolumeClaims
├── 5. 调度器本身异常（罕见）
│     └── 事件: 什么都没有 == 调度器没看到它（检查 kube-scheduler）
```

## 标准排查（每步一个假设）

```bash
# 1. 事件原文（90% 的答案在这里）
kubectl describe pod <pod> | grep -A10 "Events:"

# 2. 资源假设 → 看节点可分配 vs pod 请求
kubectl get nodes
kubectl describe node <node> | grep -A6 "Allocated resources"
kubectl get pod <pod> -o jsonpath='{.spec.containers[0].resources.requests}'

# 3. 污点假设
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{": "}{.spec.taints}{"\n"}{end}'
kubectl get pod <pod> -o jsonpath='{.spec.tolerations}'

# 4. PVC 假设
kubectl get pvc -n <ns>
kubectl get pv | grep -i release   # 是否有可用 volume

# 5. 调度器假设（事件完全空白时）
kubectl get pods -n kube-system -l component=kube-scheduler
```

## 关键陷阱

| 陷阱 | 现象 | 正确做法 |
|---|---|---|
| 只看 Pending 不看事件 | 瞎猜半天 | **Events 是 Pending 的第一现场**，90% 原因白纸黑字写在 FailedScheduling |
| 以为没资源就加节点 | 实际是 taint 或 PVC 问题 | 先读事件文本分类，别急着动基础设施 |
| 修完没确认调度 | 又卡在下个节点 | `kubectl get pod -o wide` 确认 scheduling 成功 + `kubectl describe | grep node` |

## 修复路径（dry-run 语义）

| 根因 | 修复 | 验证 |
|---|---|---|
| 资源不足 | 调小 requests / 加节点 / 清理闲置 pod | 事件变成 `Successfully assigned` |
| 污点 | 加 toleration（或用 nodeSelector 避开） | Pod 调度到目标节点 |
| nodeSelector 错 | 修正 selector / 给节点打 label | 匹配节点出现 |
| PVC 未绑定 | 建 SC / 修复 PV / 改 accessModes | PVC Bound，pod 继续调度 |

## 收尾

- 确认：`kubectl get pod -o wide` 有 node、READY 1/1
- case 记录：`cases.yaml`（tags: [pending, scheduling, taint, pvc]）
- aiops 联动：调度失败 = 事件信号 → 「FailedScheduling + 资源数据 → 原因分类」