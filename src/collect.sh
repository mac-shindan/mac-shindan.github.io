#!/bin/bash
# 計測: 実機から key=value を stdout に出す。判定は一切行わない。
# 1項目の失敗で全体を止めない。取得できなければ UNKNOWN を出す。
# sudo は使わない。プロセスは個数のみを数え、コマンドライン全文は扱わない。
set -u

emit_kv() { printf '%s=%s\n' "$1" "${2:-UNKNOWN}"; }

# --- マシン構成 ---
HW=$(system_profiler SPHardwareDataType 2>/dev/null)
# ファン有無の判定に使うのは Model Name。Model Identifier は M2以降のAirが
# "Mac14,2" 形式で "MacBookAir" を含まないため使ってはならない。
MODEL_NAME=$(printf '%s\n' "$HW" | awk -F': ' '/Model Name:/{print $2; exit}')
CHIP=$(printf '%s\n' "$HW" | awk -F': ' '/Chip:|Processor Name:/{print $2; exit}')
MEMORY_GB=$(printf '%s\n' "$HW" | awk -F': ' '/^ *Memory:/{print $2; exit}' | awk '{print $1}')
emit_kv model_name "$MODEL_NAME"
emit_kv chip       "$CHIP"
emit_kv memory_gb  "$MEMORY_GB"

# --- メモリ空き率 ---
# 実測: "System-wide memory free percentage: 33%"
FREE_PCT=$(memory_pressure 2>/dev/null \
  | awk -F': ' '/free percentage/{gsub(/%/,"",$2); print $2; exit}')
emit_kv free_pct "$FREE_PCT"

# --- スワップ使用量 (MB) ---
# 実測: "vm.swapusage: total = 21504.00M  used = 20941.19M  free = 562.81M"
SWAP_USED_MB=$(sysctl -n vm.swapusage 2>/dev/null \
  | awk '{for(i=1;i<=NF;i++) if($i=="used"){gsub(/M/,"",$(i+2)); printf "%.0f", $(i+2); exit}}')
emit_kv swap_used_mb "$SWAP_USED_MB"

# --- 圧縮メモリ (GB) ---
# 実測: "Pages occupied by compressor:            512352."  ページサイズ 16384
PAGESIZE=$(sysctl -n hw.pagesize 2>/dev/null)
COMP_PAGES=$(vm_stat 2>/dev/null \
  | awk -F': ' '/occupied by compressor/{gsub(/[ .]/,"",$2); print $2; exit}')
if [ -n "${PAGESIZE:-}" ] && [ -n "${COMP_PAGES:-}" ]; then
  COMPRESSED_GB=$(awk -v p="$COMP_PAGES" -v s="$PAGESIZE" 'BEGIN{printf "%.1f", p*s/1073741824}')
else
  COMPRESSED_GB=UNKNOWN
fi
emit_kv compressed_gb "$COMPRESSED_GB"

# --- DisplayLink の常駐有無 ---
if ps -axo comm 2>/dev/null | grep -qiE 'displaylink|evdi'; then
  emit_kv displaylink_process 1
else
  emit_kv displaylink_process 0
fi

# --- モニタ1枚ずつの接続方式 ---
# ソフトの常駐有無ではなく、モニタ自体を見る。DisplayLink の仮想ディスプレイは
# 接続方式(Connection Type)を持たないため、そこで見分けられる。
#   内蔵            -> Internal
#   直結の外部      -> DisplayPort / HDMI 等
#   DisplayLink経由 -> 情報なし
# 「DisplayLink Manager が入っているだけで使っていない」人を誤判定しないため、
# この方式に変更した（実際に誤判定の報告があった）。
DISP=$(system_profiler SPDisplaysDataType 2>/dev/null)
if [ -n "$DISP" ]; then
  COUNTS=$(printf '%s\n' "$DISP" | awk '
    /^        [^ ].*:$/ { n++; ct[n]=""; next }
    /^ +Connection Type: / { c=$0; sub(/^ +Connection Type: +/,"",c); if(n>0) ct[n]=c }
    END {
      ni=0; nd=0; nn=0
      for(i=1;i<=n;i++){ if(ct[i]=="Internal") ni++; else if(ct[i]=="") nd++; else nn++ }
      printf "%d %d", nn+nd, nd
    }')
  emit_kv external_display_count    "$(printf '%s' "$COUNTS" | awk '{print $1}')"
  emit_kv displaylink_display_count "$(printf '%s' "$COUNTS" | awk '{print $2}')"
  # 画面に根拠を出すため、モニタ名と接続方式の一覧も渡す
  emit_kv display_list "$(printf '%s\n' "$DISP" | awk '
    /^        [^ ].*:$/ { n++; nm[n]=$0; sub(/^ +/,"",nm[n]); sub(/:$/,"",nm[n]); ct[n]=""; next }
    /^ +Connection Type: / { c=$0; sub(/^ +Connection Type: +/,"",c); if(n>0) ct[n]=c }
    END { for(i=1;i<=n;i++) printf "%s%s:%s", (i>1?",":""), nm[i], (ct[i]==""?"DisplayLink":ct[i]) }')"
else
  emit_kv external_display_count    UNKNOWN
  emit_kv displaylink_display_count UNKNOWN
  emit_kv display_list              UNKNOWN
fi

# --- WindowServer の CPU 使用率 ---
# top は1サンプル目が起動からの平均になるため、必ず2サンプル取り2つ目を使う。
WS=$(top -l 2 -n 30 -stats command,cpu -o cpu 2>/dev/null \
  | grep -i '^WindowServer' | tail -1 | awk '{print $2}')
emit_kv windowserver_cpu "$WS"

# --- 熱スロットリング ---
# Apple Silicon では "No CPU power status has been recorded" となり数値が出ない。
# その場合は UNKNOWN。sudo が必要な powermetrics は使わない。
THERM=$(pmset -g therm 2>/dev/null | awk -F'= ' '/CPU_Speed_Limit/{print $2; exit}')
emit_kv cpu_speed_limit "$THERM"

# --- プロセス数（個数のみ） ---
emit_kv chrome_helper_count "$(pgrep -f 'Google Chrome Helper' 2>/dev/null | wc -l | tr -d ' ')"
emit_kv node_count          "$(pgrep -x node 2>/dev/null | wc -l | tr -d ' ')"
emit_kv claude_count        "$(pgrep -fi claude 2>/dev/null | wc -l | tr -d ' ')"

# --- メモリを多く使っているアプリ（上位5件・GB） ---
# ヘルパープロセスは親アプリに合算する。Chrome のように数十個に分かれるアプリは
# 個別に見ても判断できないため。表示するのはアプリ名と使用量のみで、
# 何のファイルを開いているか等は一切扱わない。
TOP_MEM=$(ps -axo rss,comm 2>/dev/null | awk '
  NR>1 {
    rss=$1; $1=""; p=substr($0,2)
    if (match(p, /\/[^\/]+\.app\//))      n=substr(p, RSTART+1, RLENGTH-6)
    else if (match(p, /\/[^\/]+\.app$/))   n=substr(p, RSTART+1, RLENGTH-5)
    else { k=split(p, a, "/"); n=a[k] }
    if (n != "") m[n]+=rss
  }
  END { for (k in m) printf "%.9f\t%s\n", m[k]/1048576, k }
' | sort -rn | awk -F'\t' '$1+0>=0.3 {printf "%s:%.1f\n", $2, $1}' | head -5 | paste -sd, -)
emit_kv top_mem "$TOP_MEM"

# --- 未再起動日数 ---
# 実測: "{ sec = 1785823368, usec = 946996 } Tue Aug  4 15:02:48 2026"
BOOT=$(sysctl -n kern.boottime 2>/dev/null | awk -F'[= ,]+' '{print $3}')
NOW=$(date +%s)
if [ -n "${BOOT:-}" ]; then
  emit_kv uptime_days "$(( (NOW - BOOT) / 86400 ))"
else
  emit_kv uptime_days UNKNOWN
fi
