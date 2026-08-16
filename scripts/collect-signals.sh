#!/usr/bin/env bash
# collect-signals.sh — 一键采集 Phase 3 所需信号（按需、带输出边界）
# 用法: ./collect-signals.sh <namespace> <pod> [--full]
#       --full: 追加节点与集群级信号（默认只采 pod 级）
set -euo pipefail

NS="${1:?usage: collect-signals.sh <namespace> <pod> [--full]}"
POD="${2:?usage: collect-signals.sh <namespace> <pod> [--full]}"
FULL="${3:-}"

echo "===== [1/6] pod 概览 ($NS/$POD) ====="
kubectl get pod "$POD" -n "$NS" -o wide

echo; echo "===== [2/6] 容器状态与重启 ====="
kubectl get pod "$POD" -n "$NS" -o jsonpath='{range .status.containerStatuses[*]}{.name}: ready={.ready} restarts={.restartCount} reason={.state.waiting.reason} lastReason={.lastState.terminated.reason} exit={.lastState.terminated.exitCode}{"\n"}{end}'

echo; echo "===== [3/6] 最近事件（30 条，按时间） ====="
kubectl get events -n "$NS" --sort-by=.lastTimestamp | grep -iE "$POD|Warning|Failed|BackOff|OOM|Killing" | tail -30 || true

echo; echo "===== [4/6] 崩溃前日志（--previous，若存在） ====="
kubectl logs "$POD" --previous -n "$NS" --tail=100 2>/dev/null || echo "(previous 日志不可用 —— 容器日志可能已被 CRI 清理或容器从未运行；可改用 kubectl logs $POD -n $NS --tail=50 取当前实例)"

echo; echo "===== [5/6] 实时用量 ====="
kubectl top pod "$POD" -n "$NS" 2>/dev/null || echo "(metrics-server 不可用 —— 依赖 describe 信号的 resource 字段)"

echo; echo "===== [6/6] describe 的 Conditions/Events 摘要 ====="
kubectl describe pod "$POD" -n "$NS" | grep -A8 -E "Conditions:|Events:" | head -60

if [[ "$FULL" == "--full" ]]; then
  NODE="$(kubectl get pod "$POD" -n "$NS" -o jsonpath='{.spec.nodeName}' 2>/dev/null || true)"
  if [[ -n "$NODE" ]]; then
    echo; echo "===== [extra] 节点 $NODE 条件与分配 ====="
    kubectl describe node "$NODE" | grep -A6 -E "Conditions:|Allocated resources:"
  fi
fi

echo
echo ">>> 下一动作: 对照 references/signal-map.md 判定根因；或查 cases.yaml 历史案例"