#!/bin/bash
# 判定: stdin の key=value を読み、10列TSVを stdout に出す。
# 実機に一切依存しない。テストは tests/fixtures を流し込んで行う。
#
# 列: check_id category label status measured threshold message action expect impact
#   expect = 対処するとどうなるかの目安（OK/UNKNOWN は "-"）
#   impact = 体感の改善度 大/中/小（OK/UNKNOWN は "-"）
set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/thresholds.sh"

# --- 入力の読み込み ---
# eval は使わず case のホワイトリストで受ける（想定外のキーは無視する）
FREE_PCT=UNKNOWN;            SWAP_USED_MB=UNKNOWN;   COMPRESSED_GB=UNKNOWN
DISPLAYLINK_PROCESS=UNKNOWN; EXTERNAL_DISPLAY_COUNT=UNKNOWN
WINDOWSERVER_CPU=UNKNOWN;    CPU_SPEED_LIMIT=UNKNOWN
CHROME_HELPER_COUNT=UNKNOWN; NODE_COUNT=UNKNOWN;     CLAUDE_COUNT=UNKNOWN
UPTIME_DAYS=UNKNOWN;         MODEL_NAME=UNKNOWN
CHIP=UNKNOWN;                MEMORY_GB=UNKNOWN

while IFS='=' read -r k v; do
  case "$k" in
    free_pct)               FREE_PCT="$v" ;;
    swap_used_mb)           SWAP_USED_MB="$v" ;;
    compressed_gb)          COMPRESSED_GB="$v" ;;
    displaylink_process)    DISPLAYLINK_PROCESS="$v" ;;
    external_display_count) EXTERNAL_DISPLAY_COUNT="$v" ;;
    windowserver_cpu)       WINDOWSERVER_CPU="$v" ;;
    cpu_speed_limit)        CPU_SPEED_LIMIT="$v" ;;
    chrome_helper_count)    CHROME_HELPER_COUNT="$v" ;;
    node_count)             NODE_COUNT="$v" ;;
    claude_count)           CLAUDE_COUNT="$v" ;;
    uptime_days)            UPTIME_DAYS="$v" ;;
    model_name)             MODEL_NAME="$v" ;;
    chip)                   CHIP="$v" ;;
    memory_gb)              MEMORY_GB="$v" ;;
  esac
done

# --- ヘルパ ---
# bash は小数を比較できないため awk を使う（19.7 や 8.4 を扱う）
ge() { awk -v a="$1" -v b="$2" 'BEGIN{exit !(a+0>=b+0)}'; }
lt() { awk -v a="$1" -v b="$2" 'BEGIN{exit !(a+0< b+0)}'; }

# MB を読みやすい単位にする: 20941 -> 20.4GB / 300 -> 300MB
mb_h() { awk -v m="$1" 'BEGIN{ if (m+0>=1024) printf "%.1fGB", m/1024; else printf "%dMB", m }'; }

emit() {
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$9" "${10}"
}

# --- 1. スワップ使用量 ---
if [ "$SWAP_USED_MB" = "UNKNOWN" ]; then
  emit swap 重さ "スワップ" UNKNOWN "-" "512MB未満" \
    "スワップ使用量を取得できませんでした" "-" "-" "-"
elif ge "$SWAP_USED_MB" "$TH_SWAP_NG"; then
  emit swap 重さ "スワップ" NG "$(mb_h "$SWAP_USED_MB")" "512MB未満" \
    "メモリが足りず、SSDへの退避が大量に発生しています。「固まる」の直接原因です" \
    "不要なアプリを閉じて再起動してください。何度も再発するならメモリ増設が必要です" \
    "再起動でスワップは必ず解放されます: $(mb_h "$SWAP_USED_MB") → ほぼ 0" \
    "大"
elif ge "$SWAP_USED_MB" "$TH_SWAP_WARN"; then
  emit swap 重さ "スワップ" WARN "$(mb_h "$SWAP_USED_MB")" "512MB未満" \
    "メモリがやや不足しています" \
    "使っていないアプリを閉じてください" \
    "再起動でスワップは必ず解放されます: $(mb_h "$SWAP_USED_MB") → ほぼ 0" \
    "小"
else
  emit swap 重さ "スワップ" OK "$(mb_h "$SWAP_USED_MB")" "512MB未満" \
    "メモリに余裕があります" "-" "-" "-"
fi

# --- 2. メモリ空き率 ---
if [ "$FREE_PCT" = "UNKNOWN" ]; then
  emit free_pct 重さ "メモリ空き率" UNKNOWN "-" "30%以上" \
    "メモリ空き率を取得できませんでした" "-" "-" "-"
elif lt "$FREE_PCT" "$TH_FREE_PCT_NG"; then
  emit free_pct 重さ "メモリ空き率" NG "${FREE_PCT}%" "30%以上" \
    "空きメモリがほとんどありません" \
    "使っていないアプリを閉じてください" \
    "アプリを閉じるかMacを再起動すると空き率は回復します（目標 30%以上）" \
    "大"
elif lt "$FREE_PCT" "$TH_FREE_PCT_WARN"; then
  emit free_pct 重さ "メモリ空き率" WARN "${FREE_PCT}%" "30%以上" \
    "空きメモリが少なくなっています" \
    "使っていないアプリを閉じてください" \
    "アプリを閉じると空き率は回復します（目標 30%以上）" \
    "小"
else
  emit free_pct 重さ "メモリ空き率" OK "${FREE_PCT}%" "30%以上" \
    "空きメモリは足りています" "-" "-" "-"
fi

# --- 3. 圧縮メモリ ---
if [ "$COMPRESSED_GB" = "UNKNOWN" ]; then
  emit compressed 重さ "圧縮メモリ" UNKNOWN "-" "4GB未満" \
    "圧縮メモリを取得できませんでした" "-" "-" "-"
elif ge "$COMPRESSED_GB" "$TH_COMPRESSED_NG"; then
  emit compressed 重さ "圧縮メモリ" NG "${COMPRESSED_GB}GB" "4GB未満" \
    "メモリが限界まで圧縮されています。長時間再起動していないMacで起きやすい状態です" \
    "Macを再起動してください" \
    "再起動で圧縮メモリは必ず解放されます: ${COMPRESSED_GB}GB → ほぼ 0" \
    "大"
elif ge "$COMPRESSED_GB" "$TH_COMPRESSED_WARN"; then
  emit compressed 重さ "圧縮メモリ" WARN "${COMPRESSED_GB}GB" "4GB未満" \
    "メモリの圧縮が増えています" \
    "近いうちに再起動してください" \
    "再起動で圧縮メモリは必ず解放されます: ${COMPRESSED_GB}GB → ほぼ 0" \
    "中"
else
  emit compressed 重さ "圧縮メモリ" OK "${COMPRESSED_GB}GB" "4GB未満" \
    "問題ありません" "-" "-" "-"
fi

# --- 4. モニタ接続方式 ---
# DisplayLink はモニタ映像をCPUで圧縮して転送する方式。外部モニタ接続中に
# 動いていると WindowServer のCPU使用率が跳ね上がり、Mac全体が重くなる。
if [ "$DISPLAYLINK_PROCESS" = "UNKNOWN" ] || [ "$EXTERNAL_DISPLAY_COUNT" = "UNKNOWN" ]; then
  emit display_link 重さ "モニタ接続方式" UNKNOWN "-" "直結" \
    "モニタの接続方式を取得できませんでした" "-" "-" "-"
elif [ "$DISPLAYLINK_PROCESS" = "1" ] && ge "$EXTERNAL_DISPLAY_COUNT" 1; then
  if [ "$WINDOWSERVER_CPU" = "UNKNOWN" ]; then
    DL_EXPECT="映像の圧縮処理がなくなり、画面描画のCPU負荷がほぼゼロになります"
  else
    DL_EXPECT="画面描画の負荷が下がります: ${WINDOWSERVER_CPU}% → 5%前後が目安"
  fi
  emit display_link 重さ "モニタ接続方式" NG "DisplayLink経由（外部${EXTERNAL_DISPLAY_COUNT}台）" "直結" \
    "モニタが映像圧縮方式（DisplayLink）で接続されています。CPUで映像を作っているためMac全体が重くなります。買い替えでは解決しません" \
    "USB-C／Thunderbolt でモニタをMacに直結してください。ケーブル交換（数千円）で解決します" \
    "$DL_EXPECT" \
    "大"
elif [ "$DISPLAYLINK_PROCESS" = "1" ]; then
  emit display_link 重さ "モニタ接続方式" WARN "DisplayLink常駐（外部モニタ未接続）" "直結" \
    "外部モニタは未接続ですが、DisplayLinkソフトが常駐しています" \
    "モニタを使わないなら DisplayLink Manager を終了してください" \
    "常駐分のCPUとメモリが空きます（体感の変化は小さめです）" \
    "小"
else
  emit display_link 重さ "モニタ接続方式" OK "直結" "直結" \
    "モニタは直結されています" "-" "-" "-"
fi

# --- 5. WindowServer 負荷 ---
# WindowServer は画面描画を担当するmacOS本体のプロセス。ここが高い場合、
# 原因はアプリではなくモニタの接続方式にあることが多い（項目4と併せて見る）。
if [ "$WINDOWSERVER_CPU" = "UNKNOWN" ]; then
  emit windowserver 重さ "画面描画の負荷" UNKNOWN "-" "10%未満" \
    "画面描画の負荷を取得できませんでした" "-" "-" "-"
elif ge "$WINDOWSERVER_CPU" "$TH_WS_NG"; then
  emit windowserver 重さ "画面描画の負荷" NG "${WINDOWSERVER_CPU}%" "10%未満" \
    "画面描画にCPUを使いすぎています。モニタの接続方式が原因の可能性が高いです" \
    "上の「モニタ接続方式」の結果を確認してください" \
    "モニタを直結すると ${WINDOWSERVER_CPU}% → 5%前後まで下がる見込みです" \
    "大"
elif ge "$WINDOWSERVER_CPU" "$TH_WS_WARN"; then
  emit windowserver 重さ "画面描画の負荷" WARN "${WINDOWSERVER_CPU}%" "10%未満" \
    "画面描画の負荷がやや高めです" \
    "モニタの枚数を減らすと軽くなります" \
    "モニタを1枚減らすと ${WINDOWSERVER_CPU}% から数ポイント下がります" \
    "小"
else
  emit windowserver 重さ "画面描画の負荷" OK "${WINDOWSERVER_CPU}%" "10%未満" \
    "問題ありません" "-" "-" "-"
fi

# --- 6. 熱スロットリング ---
# Apple Silicon では pmset が数値を返さないことが多く、UNKNOWN が通常の結果。
# 取得できないことを OK と偽らず、正直に「取得できません」と表示する。
if [ "$CPU_SPEED_LIMIT" = "UNKNOWN" ]; then
  emit thermal 重さ "熱による性能低下" UNKNOWN "-" "100%" \
    "このMacでは熱の数値を取得できませんでした（Apple Silicon では通常この結果になります）" \
    "判定できないため、他の項目で総合的に判断してください" "-" "-"
elif lt "$CPU_SPEED_LIMIT" "$TH_THERM_NG"; then
  emit thermal 重さ "熱による性能低下" NG "${CPU_SPEED_LIMIT}%" "100%" \
    "本体が熱くなり、CPUの性能が意図的に落とされています" \
    "ファンのないMacBook Airでは負荷の高い作業を続けると必ず起きます。台に載せて底面の風通しを確保してください" \
    "本体が冷えれば ${CPU_SPEED_LIMIT}% → 100%（本来の速度）に戻ります" \
    "大"
elif lt "$CPU_SPEED_LIMIT" "$TH_THERM_WARN"; then
  emit thermal 重さ "熱による性能低下" WARN "${CPU_SPEED_LIMIT}%" "100%" \
    "熱により性能がわずかに落ちています" \
    "底面の風通しを確保してください" \
    "本体が冷えれば ${CPU_SPEED_LIMIT}% → 100% に戻ります" \
    "小"
else
  emit thermal 重さ "熱による性能低下" OK "${CPU_SPEED_LIMIT}%" "100%" \
    "問題ありません" "-" "-" "-"
fi

# --- 7. プロセス過多 ---
# 3種類を個別に判定し、最も悪い結果をこの項目の status とする。
# プライバシー方針により、集計するのは「個数」のみ。プロセス名の全文は扱わない。
rank() { # status を比較可能な数値にする（UNKNOWN はここでは扱わない）
  case "$1" in OK) echo 0 ;; WARN) echo 1 ;; NG) echo 2 ;; *) echo 0 ;; esac
}
proc_status() { # $1=個数 $2=WARN閾値 $3=NG閾値
  if [ "$1" = "UNKNOWN" ]; then echo UNKNOWN
  elif ge "$1" "$3"; then echo NG
  elif ge "$1" "$2"; then echo WARN
  else echo OK; fi
}

S_CHROME=$(proc_status "$CHROME_HELPER_COUNT" "$TH_CHROME_WARN" "$TH_CHROME_NG")
S_NODE=$(proc_status   "$NODE_COUNT"          "$TH_NODE_WARN"   "$TH_NODE_NG")
S_CLAUDE=$(proc_status "$CLAUDE_COUNT"        "$TH_CLAUDE_WARN" "$TH_CLAUDE_NG")

# UNKNOWN を除いた最悪値を採る。そのうえで「最悪が OK なのに取得漏れがある」場合は
# OK と言い切れないため UNKNOWN に落とす（取得できなかった項目を OK にしない）。
PROC_STATUS=OK
HAS_UNKNOWN=0
for s in "$S_CHROME" "$S_NODE" "$S_CLAUDE"; do
  if [ "$s" = "UNKNOWN" ]; then
    HAS_UNKNOWN=1
    continue
  fi
  if [ "$(rank "$s")" -gt "$(rank "$PROC_STATUS")" ]; then PROC_STATUS="$s"; fi
done
if [ "$PROC_STATUS" = "OK" ] && [ "$HAS_UNKNOWN" = "1" ]; then PROC_STATUS=UNKNOWN; fi

PROC_MEASURED="Chrome ${CHROME_HELPER_COUNT}個 / node ${NODE_COUNT}個 / Claude ${CLAUDE_COUNT}個"

# Chrome の超過分から解放できるメモリの目安を出す。
# Helper 1個あたり約150MB として概算する（実測に基づく粗い目安であり保証値ではない）。
if [ "$CHROME_HELPER_COUNT" = "UNKNOWN" ]; then
  PROC_EXPECT="使っていないタブとアプリを閉じるとメモリが空きます"
else
  PROC_FREE_GB=$(awk -v c="$CHROME_HELPER_COUNT" -v t="$TH_CHROME_WARN" \
    'BEGIN{d=c-t; if(d<1){print "0"} else {printf "%.1f", d*0.15}}')
  if [ "$PROC_FREE_GB" = "0" ]; then
    PROC_EXPECT="使っていないタブとアプリを閉じるとメモリが空きます"
  else
    PROC_EXPECT="Chromeを${TH_CHROME_WARN}個まで減らすと約 ${PROC_FREE_GB}GB のメモリが空く見込みです（1個あたり約150MBの概算）"
  fi
fi

case "$PROC_STATUS" in
  NG)
    emit processes 重さ "起動中のプロセス数" NG "$PROC_MEASURED" "Chrome 30個未満" \
      "プロセスが多すぎます。1つ1つは軽くても合計でメモリを大量に消費します" \
      "使っていないChromeのタブとアプリを閉じてください" \
      "$PROC_EXPECT" "大" ;;
  WARN)
    emit processes 重さ "起動中のプロセス数" WARN "$PROC_MEASURED" "Chrome 30個未満" \
      "プロセスがやや多めです" \
      "使っていないタブを閉じてください" \
      "$PROC_EXPECT" "小" ;;
  UNKNOWN)
    emit processes 重さ "起動中のプロセス数" UNKNOWN "-" "Chrome 30個未満" \
      "プロセス数を取得できませんでした" "-" "-" "-" ;;
  *)
    emit processes 重さ "起動中のプロセス数" OK "$PROC_MEASURED" "Chrome 30個未満" \
      "問題ありません" "-" "-" "-" ;;
esac

# --- 8. 未再起動日数 ---
if [ "$UPTIME_DAYS" = "UNKNOWN" ]; then
  emit uptime 重さ "最後の再起動から" UNKNOWN "-" "7日未満" \
    "起動時刻を取得できませんでした" "-" "-" "-"
elif ge "$UPTIME_DAYS" "$TH_UPTIME_NG"; then
  emit uptime 重さ "最後の再起動から" NG "${UPTIME_DAYS}日" "7日未満" \
    "長期間再起動されていません。メモリの断片化が進み、重さの原因になります" \
    "作業を保存して再起動してください" \
    "再起動するとスワップと圧縮メモリが一度に解放されます。所要時間は2分ほどです" \
    "大"
elif ge "$UPTIME_DAYS" "$TH_UPTIME_WARN"; then
  emit uptime 重さ "最後の再起動から" WARN "${UPTIME_DAYS}日" "7日未満" \
    "そろそろ再起動をおすすめします" \
    "きりのよいところで再起動してください" \
    "再起動するとスワップと圧縮メモリが一度に解放されます。所要時間は2分ほどです" \
    "中"
else
  emit uptime 重さ "最後の再起動から" OK "${UPTIME_DAYS}日" "7日未満" \
    "問題ありません" "-" "-" "-"
fi
