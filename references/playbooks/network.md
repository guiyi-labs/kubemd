# 网络故障排障 Playbook（Service / DNS / NetworkPolicy）

> 加载条件：用户报"访问不通/超时/DNS 解析失败"，或事件无调度错误但请求失败。
> 适用失败模式：Service 不通、DNS 解析失败、网络策略误拦、CNI 异常。

## 故障树（按"从近到远"排查：先确认现象范围再判断病因）

```
网络不通
├── 0. 现象范围（先问！决定排查方向）
│     ├── 集群外 → Service?  → NodePort/LB/Ingress 层
│     ├── 集群内 pod → Service? → selector/endpoints/policy
│     ├── pod → pod?         → CNI/NetworkPolicy
│     └── 全都不通?          → CNI/节点网络
│
├── 1. Service selector 失配
│     └── 证据: kubectl get endpoints <svc> 为空
├── 2. 目标 pod 没 Ready
│     └── 证据: endpoints 有 IP 但 readiness 未通过 → 流量绕开
├── 3. NetworkPolicy 误拦
│     └── 证据: policy 存在且 selector 覆盖了源/目标; 临时禁 policy 验证
├── 4. DNS 解析失败
│     └── 证据: nslookup 失败, coredns pod 异常
├── 5. Service type 错配（ClusterIP vs NodePort vs LB）
│     └── 证据: 从错误位置访问
└── 6. CNI 异常
      └── 证据: node 上 pod 网卡/路由异常, CNI pod 崩溃
```

## 标准排查顺序（每步一个假设）

```bash
# 1. 现象范围 + endpoints（最快定位 selector 问题）
kubectl get endpoints <svc> -n <ns>
kubectl get svc <svc> -n <ns> -o wide

# 2. 目标 pod 状态
kubectl get pods -l <selector> -n <ns>
# endpoints 有 IP 但访问失败 → 查 readiness / policy / iptables-ish

# 3. DNS（从 pod 内测）
# ⚠️ busybox 需外网拉取，受限集群会失败；nslookup 也非所有镜像都有。
#    替代（解析成功=返回 IP，失败=unknown host）：
#    ① 任一带网络工具的镜像 exec 后用 Go: go run 一行 net.LookupHost
#    ② 若有 curl/wget: curl <svc>.<ns>.svc.cluster.local（TCP 级验证）
kubectl run dns-test --rm -it --image=busybox:1.36 --restart=Never \
  -- nslookup <svc>.<ns>.svc.cluster.local
kubectl get pods -n kube-system -l k8s-app=kube-dns   # coredns 健康?
kubectl get configmap -n kube-system coredns -o yaml  # 配置被改过?

# 4. NetworkPolicy（重点嫌疑时）
kubectl get netpol -n <ns>
kubectl describe netpol <name> -n <ns>   # 看 ingress/egress 规则
# 验证预测: kubectl delete netpol <name> && 重测 → 通了=policy 误拦; 不通=另有其因

# 5. CNI（全都不通时）
kubectl get pods -n kube-system | grep -iE "calico|flannel|cilium|weave"
kubectl describe node <node> | grep -A3 "NetworkUnavailable"
```

## 关键陷阱

| 陷阱 | 现象 | 正确做法 |
|---|---|---|
| 只看 Service 不看 endpoints | selector 失配但先怀疑 policy | **endpoints 永远是第一步**（0 个 IP=selector 错，有 IP 不通=往下查） |
| 在集群外测 ClusterIP | 当然不通，误判 | 先确认访问位置在不在同一网络层 |
| 禁 policy 验证后忘恢复 | 留下安全隐患 | 验证完立刻 `kubectl apply -f` 恢复，或标红警告 |
| nslookup 超时却怪 DNS | 实际是 pod 网络断 | 先确认 pod 能 ping 通别的 pod（CNI 层）再谈 DNS |

## 修复路径（dry-run 语义）

| 根因 | 修复 | 验证 |
|---|---|---|
| selector 错 | 修正 matchLabels | endpoints 出现 IP，访问通 |
| readiness 未过 | 修 pod 就绪（探针/业务） | endpoints 里 ready=true |
| policy 误拦 | 调整 policy selector/port | 恢复 policy 后仍通 |
| DNS 瘫 | 查 coredns 日志/配置、重启 | nslookup 解析成功 |
| CNI 崩 | 重建 CNI pod / 检查 node 网络 | NetworkUnavailable=False，全通 |

## 收尾

- 确认横向覆盖：同 ns 其他 pod、其他 ns、集群外入口各测一遍
- case 记录：`cases.yaml`（tags: [network, dns, netpol, service]）
- aiops 联动：这条对应网络信号（Service/Endpoint/NetPol 关联）→ 诊断规则