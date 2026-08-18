#!/bin/bash
# 描画: TSV + key=value → 自己完結HTML。外部URLを一切参照しない。
set -u
TSV="$1"
ENVF="$2"

MODEL=$(awk -F'=' '/^model_name=/{print $2}' "$ENVF")
CHIP=$(awk -F'='  '/^chip=/{print $2}'       "$ENVF")
MEM=$(awk -F'='   '/^memory_gb=/{print $2}'  "$ENVF")

N_NG=$(awk -F'\t'   '$4=="NG"{n++}   END{print n+0}' "$TSV")
N_WARN=$(awk -F'\t' '$4=="WARN"{n++} END{print n+0}' "$TSV")

# HTMLに埋め込む文字列をエスケープする
esc() { sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'; }

# 指定statusの行をカード形式で出力する
cards() {
  awk -F'\t' -v want="$1" '$4==want' "$TSV" | while IFS="$(printf '\t')" read -r id cat label st meas th msg act expect impact; do
    printf '      <div class="card %s">\n' "$st"
    printf '        <div class="label">%s</div>\n' "$(printf '%s' "$label" | esc)"
    printf '        <div class="meas">%s <span class="th">（目安: %s）</span></div>\n' \
      "$(printf '%s' "$meas" | esc)" "$(printf '%s' "$th" | esc)"
    printf '        <div class="msg">%s</div>\n' "$(printf '%s' "$msg" | esc)"
    [ "$act" = "-" ] || printf '        <div class="act">→ %s</div>\n' "$(printf '%s' "$act" | esc)"
    if [ "${expect:--}" != "-" ]; then
      printf '        <div class="expect"><span class="impact i%s">体感 %s</span>%s</div>\n' \
        "$(printf '%s' "$impact" | esc)" "$(printf '%s' "$impact" | esc)" "$(printf '%s' "$expect" | esc)"
    fi
    printf '      </div>\n'
  done
}

if [ "$N_NG" -gt 0 ]; then
  VERDICT_CLASS="ng";   VERDICT="要対応が ${N_NG} 件あります"
elif [ "$N_WARN" -gt 0 ]; then
  VERDICT_CLASS="warn"; VERDICT="注意が ${N_WARN} 件あります"
else
  VERDICT_CLASS="ok";   VERDICT="問題は見つかりませんでした"
fi

cat <<HEAD
<!doctype html><html lang="ja"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Mac 診断結果</title>
<style>
:root{--bg:#f6f7f9;--fg:#1c1f23;--card:#fff;--line:#e3e6ea;--sub:#6b7280}
@media(prefers-color-scheme:dark){:root{--bg:#16181c;--fg:#e8eaed;--card:#22252a;--line:#343840;--sub:#9aa2ad}}
*{box-sizing:border-box}
body{margin:0;padding:24px 16px 64px;background:var(--bg);color:var(--fg);
 font-family:-apple-system,BlinkMacSystemFont,"Hiragino Sans","Yu Gothic",sans-serif;line-height:1.7}
.wrap{max-width:720px;margin:0 auto}
h1{font-size:20px;margin:0 0 4px}
.meta{color:var(--sub);font-size:13px;margin-bottom:24px}
.verdict{padding:20px;border-radius:12px;font-size:22px;font-weight:700;margin-bottom:28px;border:2px solid}
.verdict.ng{background:#fde8e8;border-color:#e02424;color:#9b1c1c}
.verdict.warn{background:#fdf6b2;border-color:#c27803;color:#8e4b10}
.verdict.ok{background:#def7ec;border-color:#0e9f6e;color:#03543f}
h2{font-size:15px;margin:28px 0 10px;color:var(--sub)}
.card{background:var(--card);border:1px solid var(--line);border-left-width:5px;
 border-radius:10px;padding:14px 16px;margin-bottom:10px}
.card.NG{border-left-color:#e02424}
.card.WARN{border-left-color:#c27803}
.card.OK{border-left-color:#0e9f6e}
.card.UNKNOWN{border-left-color:#9ca3af}
.label{font-weight:700;font-size:15px}
.meas{font-size:20px;font-weight:700;margin:2px 0 6px}
.th{font-size:12px;font-weight:400;color:var(--sub)}
.msg{font-size:14px}
.act{margin-top:8px;padding:10px 12px;background:var(--bg);border-radius:8px;font-size:14px;font-weight:600}
.expect{margin-top:8px;padding:10px 12px;border:1px dashed var(--line);border-radius:8px;font-size:13px}
.impact{display:inline-block;margin-right:8px;padding:1px 8px;border-radius:99px;font-size:12px;font-weight:700;color:#fff}
.impact.i大{background:#0e9f6e}.impact.i中{background:#c27803}.impact.i小{background:#6b7280}
.note{margin-top:20px;color:var(--sub);font-size:12px}
details{margin-top:8px}summary{cursor:pointer;color:var(--sub);font-size:14px;padding:6px 0}
button{margin-top:28px;padding:12px 20px;font-size:15px;font-weight:700;cursor:pointer;
 border:1px solid var(--line);border-radius:10px;background:var(--card);color:var(--fg)}
</style></head><body><div class="wrap">
<h1>Mac 診断結果</h1>
<div class="meta">$(printf '%s' "$MODEL" | esc) / $(printf '%s' "$CHIP" | esc) / メモリ $(printf '%s' "$MEM" | esc)GB ・ $(date '+%Y-%m-%d %H:%M')</div>
<div class="verdict $VERDICT_CLASS">$VERDICT</div>
HEAD

[ "$N_NG" -gt 0 ]   && { echo '<h2>🔴 要対応</h2>'; cards NG; }
[ "$N_WARN" -gt 0 ] && { echo '<h2>🟡 注意</h2>'; cards WARN; }

echo '<details><summary>正常な項目・判定できなかった項目を表示</summary>'
cards OK
cards UNKNOWN
echo '</details>'

# コピー用テキスト（情シスへ送るかどうかは本人が判断する）
COPY=$(awk -F'\t' '{printf "%s: %s (%s)\n", $3, $4, $5}' "$TSV")
cat <<FOOT
<div class="note">「対処すると」に書かれた数値は目安です。スワップ・圧縮メモリの解放と熱の回復は確実に起きますが、
それ以外は使い方によって変わります。対処後にもう一度診断すると実際の数値を確認できます。</div>
<button onclick="navigator.clipboard.writeText(document.getElementById('raw').textContent);this.textContent='コピーしました'">結果をコピー</button>
<pre id="raw" style="display:none">$(printf '%s' "$MODEL / $CHIP / メモリ ${MEM}GB" | esc)
$(printf '%s' "$COPY" | esc)</pre>
</div></body></html>
FOOT
