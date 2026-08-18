#!/bin/bash
# 設置済みアプリの自動更新。診断結果を表示したあとに実行する。
#
# 実行中のアプリをその場で差し替えるとスクリプトの読み込みが壊れるため、
# 新しい版は待避所に用意し、アプリ終了後に別プロセスが入れ替える。
#
# 通信するのは配布サイトへの取得のみ。Macの情報は一切送信しない。
set -u

DEST="$HOME/Applications/Mac診断.app"
ID_URL="${MACDOCTOR_ID_URL:-https://mac-shindan.github.io/BUILD_ID}"
ZIP_URL="${MACDOCTOR_ZIP_URL:-https://github.com/mac-shindan/mac-shindan.github.io/releases/latest/download/Mac-Shindan.zip}"
STAGE="$HOME/Library/Caches/jp.macshindan.diagnostic"

# 設置済みでなければ何もしない（一時フォルダから実行された場合など）
[ -d "$DEST" ] || exit 0

LOCAL_ID=$(cat "$DEST/Contents/Resources/macdoctor/BUILD_ID" 2>/dev/null || echo "")
[ -n "$LOCAL_ID" ] || exit 0

# 5秒で諦める。ネットワークが遅くても診断の邪魔をしない。
REMOTE_ID=$(curl -fsSL --max-time 5 "$ID_URL" 2>/dev/null | tr -d '[:space:]')
[ -n "$REMOTE_ID" ] || exit 0
[ "$REMOTE_ID" = "$LOCAL_ID" ] && exit 0

rm -rf "$STAGE"
mkdir -p "$STAGE" || exit 0
curl -fsSL --max-time 60 -o "$STAGE/new.zip" "$ZIP_URL" 2>/dev/null || { rm -rf "$STAGE"; exit 0; }
ditto -x -k "$STAGE/new.zip" "$STAGE/x" 2>/dev/null || { rm -rf "$STAGE"; exit 0; }

NEW="$STAGE/x/Mac診断.app"
[ -d "$NEW" ] || { rm -rf "$STAGE"; exit 0; }

# 取得したものが本当に新しい版か確認してから入れ替える
NEW_ID=$(cat "$NEW/Contents/Resources/macdoctor/BUILD_ID" 2>/dev/null || echo "")
[ "$NEW_ID" = "$REMOTE_ID" ] || { rm -rf "$STAGE"; exit 0; }

# アプリ終了後に入れ替える。親から切り離し、出力も閉じる
# （do shell script は出力が閉じるまで待つため、閉じないと診断が終わらない）
LSREG=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
nohup /bin/bash -c "
  sleep 8
  /usr/bin/ditto '$NEW' '$DEST' 2>/dev/null
  /usr/bin/xattr -dr com.apple.quarantine '$DEST' 2>/dev/null
  [ -x '$LSREG' ] && '$LSREG' -f '$DEST' >/dev/null 2>&1
  /bin/rm -rf '$STAGE'
" >/dev/null 2>&1 &

echo "update-scheduled: $LOCAL_ID -> $REMOTE_ID"
