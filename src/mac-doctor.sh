#!/bin/bash
# 実行本体: 計測 → 判定 → 描画 → 表示。
# 結果は本人のデスクトップにのみ保存する。外部への自動送信は一切行わない。
set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

OUT="$HOME/Desktop/Mac診断結果_$(date '+%Y-%m-%d_%H%M').html"

bash "$SCRIPT_DIR/collect.sh"                      > "$TMP/raw.env"    || exit 1
bash "$SCRIPT_DIR/judge.sh" < "$TMP/raw.env"       > "$TMP/result.tsv" || exit 1
bash "$SCRIPT_DIR/report.sh" "$TMP/result.tsv" "$TMP/raw.env" > "$OUT" || exit 1

open "$OUT"

# 診断結果を見せたあとで、次回をワンクリックにする設置を提案する。
# 先に結果を出すことで、初回の待ち時間を増やさない。
# SCRIPT_DIR は .app 内では Contents/Resources/macdoctor を指す。
APP_SRC=$(cd "$SCRIPT_DIR/../../.." 2>/dev/null && pwd) || APP_SRC=""
[ -n "$APP_SRC" ] && bash "$SCRIPT_DIR/install.sh" "$APP_SRC" || true
