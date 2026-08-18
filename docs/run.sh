#!/bin/bash
# Mac診断 ワンライナー実行用。
#
#   curl -sL https://mac-shindan.github.io/run.sh | bash
#
# Finder からアプリを開くと Gatekeeper の検査対象になり、公証のないアプリは
# macOS 15 以降ブロックされる。この経路はシェルスクリプトを直接実行するため
# 検査を通らず、どの macOS でも確実に動く。
# 実行後に ~/Applications へ設置すれば検疫属性が外れ、次回からは Dock から起動できる。
set -eu

DOWNLOAD_URL="https://github.com/mac-shindan/mac-shindan.github.io/releases/latest/download/Mac-Shindan.zip"

echo "Mac診断をダウンロードしています..."
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

if ! curl -fsSL -o "$TMP/app.zip" "$DOWNLOAD_URL"; then
  echo "エラー: ダウンロードに失敗しました。ネットワークを確認してください。" >&2
  exit 1
fi

if ! ditto -x -k "$TMP/app.zip" "$TMP/x" 2>/dev/null; then
  echo "エラー: ファイルを展開できませんでした。" >&2
  exit 1
fi

RUNNER="$TMP/x/Mac診断.app/Contents/Resources/macdoctor/mac-doctor.sh"
if [ ! -f "$RUNNER" ]; then
  echo "エラー: 診断プログラムが見つかりませんでした。" >&2
  exit 1
fi

echo "診断中です。10秒ほどお待ちください..."
bash "$RUNNER"
