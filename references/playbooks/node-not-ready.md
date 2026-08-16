# 节点异常排障 Playbook（NotReady / 压力条件）

> 加载条件：节点 `NotReady`，或 pod 无端漂移/被杀，或监控显示节点异常。
> 适用失败模式：kubelet 失联 / 资源压力 / 磁盘 / 网络 / 容器运行时异常。
> ⚠️ 验证需真实/多节点环境：单节点 kind 模拟 NotReady（杀 kubelet/docker stop）会同时击穿控制面，风险高于收益；建议在 EKS/GKE 或多节点 kind（3+)下验证本 playbook 命令。

## 故障树

```
Node NotReady
├── 1. kubelet 失联（最常见根因）
│     └── 证据: NotReady 伴随 LastHeartbeatTime 很久之前; kubelet 服务 down/重启
├── 2. 资源压力（Memory/Disk/PID Pressure）
│     └── 证据: describe node Conditions 有 Pressure=True
├── 3. 容器运行时异常（containerd/docker）
│     └── 证据: kubelet 起来但拿不到容器状态; runtime socket 连不上
├── 4. 节点网络故障
│     └── 证据: 节点网络失联（不只是集群内）; CNI 报错
└── 5. 系统级（磁盘满 / 内核问题 / oom-killer 屠节点）
      └── 证据: df -h 满 或 dmesg 内核报错
```

## 标准排查（每步一个假设）

```bash
# 1. 节点状态 + 心跳 + 条件
kubectl describe node <node>
kubectl get node <node> -o jsonpath='{.status.conditions}'
# Ready=False? LastHeartbeatTime 离现在多久?

# 2. 上节点看真相（kubelet 是本地服务，describe 看不到 kernel 细节）
ssh <node>
systemctl status kubelet            # 在跑? 崩了? 没起来?
journalctl -u kubelet --since "10 min ago" | tail -50   # kubelet 说啥了
df -h && free -m                    # 磁盘/内存
dmesg | tail -30                    # 内核（OOM/panic/IO error）

# 3. 运行时
systemctl status containerd
crictl ps   # 运行时能否列出容器

# 4. 回集群侧看归属（CNI/网络）
kubectl get pods -n kube-system -o wide | grep <node>
```

## 关键陷阱

| 陷阱 | 现象 | 正确做法 |
|---|---|---|
| 只在集群侧看 | describe 只能看到"失联"表象，看不到磁盘满 | **必须 SSH 上节点看 kubelet/内核** |
| 重启 kubelet 了事 | 根因是磁盘满，重启又倒 | 先看 journalctl 找根因再动作 |
| 驱逐误判 | 节点 ResourcePressure 时 pod 被杀不是应用问题 | 看是否 node 压力（Kubelet eviction 事件），别查应用 |

## 修复路径

| 根因 | 修复 | 验证 |
|---|---|---|
| kubelet 失联 | 查 journalctl 根因 → 修配置/重启；系统级问题先修系统 | Ready=True, heartbeat 恢复 |
| 磁盘满 | 清日志/镜像/扩容 | df 有余量, 条件解除 |
| 运行时异常 | 修 containerd; 必要时 drain + 重新调度 | crictl 正常 |
| 网络故障 | 修节点网络/CNI | NetworkUnavailable=False |

节点恢复动作的护栏（受控运维语义）：
```bash
# 维护节点前先腾空（把工作负载安全挪走）
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data
# 恢复后
kubectl uncordon <node>
```

## 收尾

- 确认：`kubectl get node` Ready + 压力条件全部 False + 工作负载回来
- case 记录：`cases.yaml`（tags: [node, notready, kubelet, disk]）
- aiops 联动：节点信号（条件 + 心跳）→ 「节点级根因 + 受影响工作负载影响面」