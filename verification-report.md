# DSH skill `dsh-k8s-diagnosis` 真实环境验证报告

> 验证人：aiops-platform 会话（deepseek-v4-pro）
> 日期：2026-08-16
> 环境：kind v0.32.0 单节点集群 `kind-diag`，K8s v1.36.1，CNI=kindnet
> （v0.32 实测支持 NetworkPolicy iptables enforcement）
> 故障注入：自建 scratch 镜像 `diag-tools:v1`（crasher/oomer/httpserver 三个
> Go 静态二进制，`kind load` 导入，不依赖外网镜像拉取）
> 约束：本报告**不改 skill 文件**；**不 git commit**（落盘供指挥中枢读取）。

---

## 0. 环境与故障注入清单

| 故障场景 | Deployment | 注入方式 | 达到状态 |
|---|---|---|---|
| CrashLoopBackOff | crash-app | `/crasher`（Go：stderr 打印 fatal + `os.Exit(1)`） | `CrashLoopBackOff`, restarts 6 |
| OOMKilled | oom-app | `/oomer 256`（`make([]byte,256Mi)` 逐页 touch，memory limit=32Mi） | `OOMKilled`, exit 137, restarts 6 |
| ImagePullBackOff | img-app | 镜像 `registry.invalid/nope:v9`（不存在） | `ImagePullBackOff` |
| Pending | pending-app | requests `cpu:500, memory:500Gi`（远超节点） | `Pending` + FailedScheduling |
| NetworkPolicy 误拦 | web + web-svc + deny-web-ingress | `/httpserver` 监听 :8080；svc 80→8080；netpol ingress 阻断 app=web | 拦截生效/解除可复现 |

---

## 1. 各 playbook 逐条命令实测

### 1.1 `references/playbooks/crashloop.md`

| # | 命令 | 实测结果 | 判定 |
|---|---|---|---|
| 32 | `kubectl get events --sort-by=.lastTimestamp -n <ns> \| tail -20` | `Warning BackOff pod/crash-app... Back-off restarting failed container crash in pod crash-app-...` | ✅ 通过 |
| 33 | `kubectl get pod <pod> -n <ns> -o wide` | `crash-app-... 0/1 CrashLoopBackOff 6 10.244.0.19 diag-control-plane` | ✅ 通过 |
| 36 | `kubectl logs <pod> --previous -n <ns> --tail=200` | **首次失败**：`unable to retrieve container logs for containerd://...`；5+ 分钟后重跑成功：`app starting... fatal: unable to read config.json: no such file or directory` | ⚠️ 需修正（见 §3-1） |
| 39 | `kubectl get pod <pod> -o jsonpath='{range .status.containerStatuses[*]}{.name}: restarts={.restartCount} lastReason={.lastState.terminated.reason} exit={.lastState.terminated.exitCode}{"\n"}{end}'` | `crash: restarts=6 lastReason=Error exit=1` | ✅ 通过，输出格式与 playbook 注释一致 |
| 44 | `kubectl describe pod <pod>`（假设验证） | Events: `Warning BackOff 72s (x11 over 10m) kubelet Back-off restarting failed container crash` | ✅ 通过 |
| 62 | `kubectl rollout undo deployment/<name> -n <ns>` | 语法正确；场景无真实可回滚变更（dry-run 语义未触发） | ✅ 语法正确 |

### 1.2 `references/playbooks/oom.md`

| # | 命令 | 实测结果 | 判定 |
|---|---|---|---|
| 9 | `kubectl get pod <pod> -n <ns> -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}'` | `OOMKilled` | ✅ 通过 |
| 11 | `kubectl get events -n <ns> --sort-by=.lastTimestamp \| tail -10`（注释声称"OOMKilling 事件会出现"） | **无 OOMKilling Warning 事件**，仅有 `Warning BackOff ... Back-off restarting failed container oom` | ⚠️ 需修正（见 §3-2） |
| 37 | `kubectl top pod <pod> -n <ns>` | `error: Metrics API not available`（kind 默认无 metrics-server） | ⚠️ 需修正（见 §3-3） |
| 40 | `kubectl get pod <pod> -o jsonpath='{range .spec.containers[*]}{.name}: req={.resources.requests} lim={.resources.limits}{"\n"}{end}'` | `oom: req={"memory":"16Mi"} lim={"memory":"32Mi"}` | ✅ 通过 |
| 43 | `kubectl top node` | `error: Metrics API not available` | ⚠️ 同 §3-3 |
| 44 | `kubectl describe node <node> \| grep -A5 "Conditions"` | Conditions: `MemoryPressure False / DiskPressure False / Ready True` | ✅ 通过 |
| 51 | `kubectl get pod <pod> -o jsonpath='{.status.containerStatuses[0].restartCount}'` | 3 → 6，递增 | ✅ 通过 |
| — | `describe pod` Last State | `Reason: OOMKilled / Exit Code: 137` | ✅ 通过 |

### 1.3 `references/playbooks/network.md`

| # | 命令 | 实测结果 | 判定 |
|---|---|---|---|
| 34 | `kubectl get endpoints <svc> -n <ns>` | `web-svc 10.244.0.20:8080` | ✅ 通过 |
| 35 | `kubectl get svc <svc> -n <ns> -o wide` | `web-svc ClusterIP 10.96.243.21 <none> 80/TCP app=web` | ✅ 通过 |
| 38 | `kubectl get pods -l <selector> -n <ns>` | `web-5dd9775f96-mdgn5 1/1 Running` | ✅ 通过 |
| 42-43 | `kubectl run dns-test --rm -it --image=busybox:1.36 --restart=Never -- nslookup <svc>.<ns>.svc.cluster.local` | 集群外网受限无法拉 busybox；改用 Go `net.LookupHost` 实测：`DNS_OK [10.96.243.21]` | ⚠️ 需修正（见 §3-4） |
| 44 | `kubectl get pods -n kube-system -l k8s-app=kube-dns` | `coredns-... 1/1 Running`（2 副本） | ✅ 通过 |
| 45 | `kubectl get configmap -n kube-system coredns -o yaml` | `kubernetes cluster.local in-addr.arpa ip6.arpa {` / `forward . /etc/resolv.conf` | ✅ 通过 |
| 48-49 | `kubectl get netpol -n <ns>` + `kubectl describe netpol <name> -n <ns>` | `deny-web-ingress app=web`；`PodSelector: app=web / Policy Types: Ingress` | ✅ 通过 |
| 50 | **验证预测**：`kubectl delete netpol <name> && 重测 → 通了=policy 误拦` | 实测闭环：**apply 后** pod→svc HTTP 超时（`context deadline exceeded`）；**delete 后** `HTTP 200 hello from web-backend`；**恢复 apply 后**再次超时 | ✅ **核心验证预测通过**（kindnet v0.32 实测支持 netpol enforcement） |
| 53 | `kubectl get pods -n kube-system \| grep -iE "calico\|flannel\|cilium\|weave"` | 输出 kindnet（CNI 识别） | ✅ 通过 |

### 1.4 `references/playbooks/node-not-ready.md`

**未实测**：kind 单节点集群模拟 NotReady（杀 kubelet / docker stop 节点）会使整个控制面不可用，风险高于收益。涉及的命令（`kubectl describe node` / `ssh <node>` / `systemctl status kubelet` / `journalctl -u kubelet` / `crictl ps` / `kubectl drain`）均为标准运维命令，建议在多节点环境（EKS/GKE 或 3-node kind）下验证。

### 1.5 `references/playbooks/pending.md`

| # | 命令 | 实测结果 | 判定 |
|---|---|---|---|
| 9 | `kubectl describe pod <pod> \| grep -A10 "Events:"` | `Warning FailedScheduling: 0/1 nodes are available: 1 Insufficient cpu, 1 Insufficient memory. no new claims to deallocate, preemption: 0/1...` | ✅ 通过 |
| 38 | `kubectl get pod <pod> -o jsonpath='{.spec.containers[0].resources.requests}'` | `{"cpu":"500","memory":"500Gi"}` | ✅ 通过 |
| 36 | `kubectl get nodes` | `diag-control-plane Ready` | ✅ 通过 |
| 37 | `kubectl describe node <node> \| grep -A6 "Allocated resources"` | `cpu 950m (47%) / memory 306Mi (15%)` | ✅ 通过 |
| 41 | `kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{": "}{.spec.taints}{"\n"}{end}'` | `diag-control-plane: `（无污点，纯资源不足） | ✅ 通过 |
| 58 | `kubectl get pod <pod> -o wide` 确认调度 | `Pending 0 <none>`（未调度） | ✅ 通过（故障态正确呈现） |

### 1.6 ImagePullBackOff（补充实测，非 playbook 文件）

| 命令 | 实测结果 | 判定 |
|---|---|---|
| `kubectl get events \| grep -iE "pull\|img"` | `Failed to pull image "registry.invalid/nope:v9": failed to resolve ... no such host` → `Error: ErrImagePull` → `Error: ImagePullBackOff` | ✅ |
| `kubectl get pod -o jsonpath='{.status.containerStatuses[0].state.waiting.reason}'` | `ImagePullBackOff` | ✅ |

---

## 2. `scripts/collect-signals.sh` 实测

用法：`./collect-signals.sh <namespace> <pod> [--full]`。在 crash-app（CrashLoopBackOff）与 oom-app（OOMKilled）上各跑一次（均带 `--full`）。

### 2.1 crash-app 实测

| 步骤 | 实测输出（关键行） | 判定 |
|---|---|---|
| [1/6] pod 概览 | `crash-app-... 0/1 CrashLoopBackOff 6 (5m ago) 10m 10.244.0.19 diag-control-plane` | ✅ |
| [2/6] 容器状态与重启 | `crash: ready=false restarts=6 reason=CrashLoopBackOff lastReason=Error exit=1` | ✅ 字段完整 |
| [3/6] 最近事件 | grep 过滤（pod 名/Warning/Failed/BackOff/OOM/Killing）tail 30 正常 | ✅ |
| [4/6] 崩溃前日志 | 首次：`unable to retrieve container logs for containerd://...`；稍后重跑：`app starting... / fatal: unable to read config.json` | ⚠️ 同 §3-1/§3-5 |
| [5/6] 实时用量 | `(metrics-server 不可用 —— 依赖 describe 信号的 resource 字段)` | ✅ 降级文案正确 |
| [6/6] Conditions/Events | Conditions: `PodScheduled True / Ready False / ContainersReady False`；Events: Scheduled/Pulled/Created/Started/BackOff | ✅ |
| [--full] 节点 | `MemoryPressure False / DiskPressure False / Ready True`；Allocated resources: `cpu 950m (47%) / memory 306Mi (15%)` | ✅ |

### 2.2 oom-app 实测

| 步骤 | 实测输出 | 判定 |
|---|---|---|
| [1/6] | `oom-app-... 0/1 OOMKilled 6 (3m38s ago)` | ✅ |
| [2/6] | `oom: ready=false restarts=6 lastReason=OOMKilled exit=137` | ✅ 核心信号正确 |
| [4/6] | `unable to retrieve container logs for containerd://...`（OOM 容器快速回收） | ⚠️ 同 §3-5 |
| [5/6] | `(metrics-server 不可用 ...)` | ✅ |
| [--full] | 节点 MemoryPressure=False + allocated 正常 | ✅ |

**脚本本身**：所有 kubectl 命令语法正确、无报错；grep/`|| true`/`2>/dev/null` 处理合理；无输出结构不符预期。**唯一问题**在 [4/6] 降级文案（§3-5）。

---

## 3. 明确修正点清单（文件 + 行号 + 正确写法）

| # | 文件 | 位置 | 现状 | 问题 | 建议修正 |
|---|---|---|---|---|---|
| 1 | `references/playbooks/crashloop.md` | 第 36 行 `kubectl logs <pod> --previous -n <ns> --tail=200` | 作为"拿到真声"唯一手段 | terminated 容器日志被 containerd 时序清理时失败（实测首次拿不到，5+ 分钟后才成功） | 补充兜底：`--previous` 返回 "unable to retrieve container logs" 时改用 `kubectl logs <pod> -n <ns> --tail=200`（当前实例最后输出），两者结合 |
| 2 | `references/playbooks/oom.md` | 第 11-12 行 `kubectl get events ...` 与注释"OOMKilling 事件会出现" | 假设 OOMKilling Warning 必然出现 | kind/containerd v2 实测**不产生** OOMKilling 事件；只有 BackOff + `lastState.terminated.reason=OOMKilled` | 改为："OOMKilling 事件因平台/CRI 而异（kind 上不出现）。**以 `lastState.terminated.reason==OOMKilled` + exit 137 为准**；BackOff 只表明重启循环，非 OOM 直接证据" |
| 3 | `references/playbooks/oom.md` | 第 37、43 行 `kubectl top pod/node` | 作为量化测量核心 | 依赖 metrics-server；kind 默认未装 → `Metrics API not available`；无前置说明 | 补充："`kubectl top` 需 metrics-server。未装时：① 用 resources jsonpath 确认 limit；② 参考 collect-signals.sh [5/6] 降级信号。安装：`kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml`（kind 需加 `--kubelet-insecure-tls`）" |
| 4 | `references/playbooks/network.md` | 第 42-43 行 `kubectl run dns-test --rm -it --image=busybox:1.36 ... nslookup` | busybox + nslookup 唯一路径 | 外网受限集群拉不到 busybox；nslookup 非所有环境可用 | 补充替代：pod 内 `net.LookupHost`（Go）/ `curl <svc>.<ns>.svc.cluster.local`（解析成功=有 IP，失败=unknown host），busybox 为推荐非唯一 |
| 5 | `scripts/collect-signals.sh` | 第 21 行 `... \|\| echo "(无 previous 日志 —— 可能未崩溃过)"` | 降级文案"可能未崩溃过" | OOMKilled 等真实崩溃场景 previous 也可能取不到（CRI 清理），文案误导 | 改为："(previous 日志不可用 —— 容器日志可能已被 CRI 清理或容器从未运行；可改用 `kubectl logs <pod> -n <ns> --tail=50` 取当前实例)" |
| 6 | `references/playbooks/node-not-ready.md` | 全文 | 需 ssh 上节点 + systemctl/journalctl | 单节点 kind 无法安全模拟（杀 kubelet 自毁控制面）；命令本身为标准运维 | 建议在多节点环境补验；可在 playbook 注明"验证需真实/多节点环境" |

**无 ❌ 硬错误**：所有命令语法正确、无字段缺失、无参数错误；问题集中在**环境依赖假设**（metrics-server、busybox、previous 日志可用性）与**平台差异**（OOMKilling 事件）。

---

## 4. 边界确认

- **只用了 kind-diag 集群**（`kind create cluster --name diag`，context `kind-diag`，K8s v1.36.1）
- **未动 bootstrap-day2**：其集群/Go 代码/config 零改动
- **未动 e5-deploy VM**（本次验证全程在本地 Mac + kind 容器内）
- 故障注入镜像 `diag-tools:v1` 为自建 scratch 镜像（/tmp/dsh-verify/），`kind load` 导入，未触碰任何仓库代码
- 本报告落盘于 aiops 仓库 `docs/skill-verification-kubemd.md`，**未 git commit**（untracked）
- kind-diag 集群与 5 个故障 Deployment 保留运行，供指挥中枢复验；不需要时可 `kind delete cluster --name diag` 清理
