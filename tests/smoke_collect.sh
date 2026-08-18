#!/bin/bash
# collect.sh は実機依存のため、値そのものではなく「契約」だけを検証する。
. "$(cd "$(dirname "$0")" && pwd)/run.sh"

OUT=$(bash "$SRC_DIR/collect.sh" 2>/dev/null)

echo "== 必須キーがすべて出力される =="
for k in model_name chip memory_gb free_pct swap_used_mb compressed_gb \
         displaylink_process external_display_count windowserver_cpu \
         cpu_speed_limit chrome_helper_count node_count claude_count uptime_days; do
  if echo "$OUT" | grep -q "^${k}="; then
    PASSED=$((PASSED+1)); printf '  ok   key %s\n' "$k"
  else
    FAILED=$((FAILED+1)); printf '  FAIL key %s が出力されていない\n' "$k"
  fi
done

echo "== 出力行数がちょうど14である =="
n_lines=$(printf '%s\n' "$OUT" | grep -c '=')
assert_eq "14行を出力する" 14 "$n_lines"

echo "== 実測できた項目が10以上ある =="
# 空出力や全滅を検知する。UNKNOWN が通常経路なのは cpu_speed_limit のみ。
n_real=$(printf '%s\n' "$OUT" | grep '=' | grep -vc '=UNKNOWN$')
if [ "$n_real" -ge 10 ]; then
  PASSED=$((PASSED+1)); printf '  ok   実測できた項目 %s件\n' "$n_real"
else
  FAILED=$((FAILED+1)); printf '  FAIL 実測できた項目が少なすぎる (%s件)\n' "$n_real"
fi

echo "== collect の出力が judge を通る =="
n=$(echo "$OUT" | bash "$SRC_DIR/judge.sh" | wc -l | tr -d ' ')
assert_eq "judge.sh が8項目を返す" 8 "$n"

finish
