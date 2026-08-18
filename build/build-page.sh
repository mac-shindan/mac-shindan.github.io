#!/bin/bash
# 配布ページを生成する。
#
# ダウンロードは GitHub Release の固定 URL を指す。
# 以前はページに zip を base64 で埋め込んでいたが、共有ページは制限付きの枠内で
# 表示されるためファイル保存がブロックされ、無反応になった。実体のある URL を
# 指すこと。ページ内にファイルを埋め込み直してはならない。
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/Mac診断.app"
# リリースに上げるファイル名と一致させる。別名にすると古い zip を
# 配布してしまう事故が起きる（実際に一度起きた）。
ZIP="$ROOT/build/Mac-Shindan.zip"
TPL="$ROOT/build/page-template.html"
OUT="$ROOT/build/distribute.html"

# ダウンロード先。Release を作り直しても URL は変わらない。
# 置き場所はここ1か所で切り替える。個人アカウント名をURLに出さないため、
# 公開先は組織アカウント配下に置く。
PUBLIC_REPO="${MACDOCTOR_PUBLIC_REPO:-mac-shindan/mac-shindan.github.io}"
DOWNLOAD_URL="${MACDOCTOR_DOWNLOAD_URL:-https://github.com/${PUBLIC_REPO}/releases/latest/download/Mac-Shindan.zip}"

# 常に最新のスクリプトを含んだアプリから作り直す
bash "$ROOT/build/build-app.sh" >/dev/null

rm -f "$ZIP"
# ditto は実行権限とリソースフォークを保ったまま圧縮する。
# zip コマンドではアプリの実行権限が失われる場合がある。
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

SIZE=$(awk -v b="$(wc -c < "$ZIP" | tr -d ' ')" 'BEGIN{printf "%.0f KB", b/1024}')
DATE=$(date '+%Y-%m-%d')

# テンプレートは <title> と <style> から始まる断片なので、
# 単体で開ける完全な HTML 文書に包む。GitHub Pages で配信するため必須。
{
  printf '%s\n' '<!doctype html>' '<html lang="ja">' '<head>' \
    '<meta charset="utf-8">' \
    '<meta name="viewport" content="width=device-width,initial-scale=1">'
  awk -v url="$DOWNLOAD_URL" -v size="$SIZE" -v d="$DATE" '
    { line=$0
      gsub(/__DOWNLOAD_URL__/, url,  line)
      gsub(/__ZIP_SIZE__/,     size, line)
      gsub(/__BUILD_DATE__/,   d,    line)
      print line
      if (line ~ /^<\/style>/) print "</head>\n<body>" }
  ' "$TPL"
  printf '%s\n' '</body>' '</html>'
} > "$OUT"

# ターミナル実行用のワンライナーも同じURLで生成する
sed "s|__DOWNLOAD_URL__|$DOWNLOAD_URL|g" "$ROOT/build/run-template.sh" > "$ROOT/build/run.sh"
chmod +x "$ROOT/build/run.sh"

# 差し込み漏れがあれば失敗させる
if grep -q '__DOWNLOAD_URL__' "$ROOT/build/run.sh"; then
  echo "エラー: run.sh にプレースホルダが残っています" >&2
  exit 1
fi
if grep -q '__DOWNLOAD_URL__\|__ZIP_SIZE__\|__BUILD_DATE__' "$OUT"; then
  echo "エラー: プレースホルダが残っています" >&2
  exit 1
fi

echo "生成しました: $OUT ($(wc -c < "$OUT" | tr -d ' ') bytes)"
echo "ダウンロード先: $DOWNLOAD_URL"
