#!/usr/bin/env bash
# record-case.sh — 追加一条诊断案例到 cases.yaml（本地 MVP 案例库）
# 用法: ./record-case.sh "<symptom>" "<root_cause>" "<fix>" [tags...]
# 例:   ./record-case.sh "pod CrashLoopBackOff after :latest" "unpinned tag + missing config" "pin digest + add config volume" crashloop image-tag config
set -euo pipefail

CASES="${CASES_FILE:-$(dirname "$0")/../cases.yaml}"
SYMPTOM="${1:?usage: record-case.sh <symptom> <root_cause> <fix> [tags...]}"
ROOT_CAUSE="${2:?usage: record-case.sh <symptom> <root_cause> <fix> [tags...]}"
FIX="${3:?usage: record-case.sh <symptom> <root_cause> <fix> [tags...]}"
shift 3

TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
TAGS="$*"

cat >> "$CASES" <<EOF

- id: case-$(date -u +%Y%m%d%H%M%S)
  recorded_at: $TS
  symptom: "$SYMPTOM"
  root_cause: "$ROOT_CAUSE"
  fix: "$FIX"
  verification: "pending"   # 修复后手动更新为 kubectl 验证结果
  tags: [$TAGS]
EOF

echo "✅ case 已追加: $CASES"
echo "   下一步: 修复验证通过后，把 verification 从 pending 改为实际结果"