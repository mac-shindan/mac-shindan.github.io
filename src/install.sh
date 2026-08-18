#!/bin/bash
# 次回からワンクリックで使えるようにする（任意・初回のみ）。
#   $1 = コピー元の Mac診断.app のパス
#
# ~/Applications に置くため管理者パスワードは不要。
# 設置した控えは検疫属性を外すので、2回目以降は右クリックも警告も不要になる。
# 診断そのものは既に完了しているため、ここで失敗しても診断結果には影響しない。
set -u

APP_SRC="${1:-}"
DEST="$HOME/Applications/Mac診断.app"

# .app の外（開発中のソース実行）なら何もしない
case "$APP_SRC" in
  *.app) ;;
  *) exit 0 ;;
esac
[ -d "$APP_SRC" ] || exit 0

# すでに設置済み、または設置先から起動された場合は何もしない
[ "$APP_SRC" = "$DEST" ] && exit 0
[ -e "$DEST" ] && exit 0

# テスト時は MACDOCTOR_INSTALL_ANSWER で応答を差し込む（ダイアログを出さない）
ANSWER="${MACDOCTOR_INSTALL_ANSWER:-}"
if [ -z "$ANSWER" ]; then
  ANSWER=$(osascript \
    -e 'display dialog "次回からワンクリックで診断できるようにしますか？

アプリを「アプリケーション」に入れて Dock に追加します。
管理者パスワードは必要ありません。" buttons {"あとで", "追加する"} default button "追加する" with title "Mac診断"' \
    -e 'button returned of result' 2>/dev/null) || ANSWER="あとで"
fi
[ "$ANSWER" = "追加する" ] || exit 0

mkdir -p "$HOME/Applications"
ditto "$APP_SRC" "$DEST" || exit 0

# 検疫属性を外す。利用者が一度起動を許可したアプリの控えなので、
# 次回以降に「開発元を検証できません」を出す必要はない。
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true

# Dock に追加する
defaults write com.apple.dock persistent-apps -array-add "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>$DEST</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>" 2>/dev/null || true
killall Dock 2>/dev/null || true

if [ -z "${MACDOCTOR_INSTALL_ANSWER:-}" ]; then
  osascript -e 'display dialog "Dock に追加しました。

次からは Dock のアイコンをクリックするだけで診断できます。" buttons {"OK"} default button "OK" with title "Mac診断"' >/dev/null 2>&1 || true
fi

echo "installed: $DEST"
