#!/bin/bash
# 配布用の Mac診断.app を生成する。macOS標準の osacompile のみを使う。
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/Mac診断.app"

rm -rf "$APP"

# path to me でアプリ自身の場所を得て、同梱したシェルスクリプトを実行する。
# do shell script はターミナルを開かない。
osacompile -o "$APP" <<'APPLESCRIPT'
on runDiagnosis()
	set myPath to POSIX path of (path to me)
	set runner to quoted form of (myPath & "Contents/Resources/macdoctor/mac-doctor.sh")
	try
		do shell script "/bin/bash " & runner
	on error errMsg
		display dialog "診断中に問題が発生しました。情シスに次の内容を伝えてください：" & return & return & errMsg buttons {"OK"} default button "OK" with icon caution
	end try
end runDiagnosis

-- アイコンをダブルクリック／Dock から起動した場合
on run
	runDiagnosis()
end run

-- 結果画面の「もう一度診断する」ボタン（macshindan://）から起動した場合。
-- この受け口が無いと、リンク経由ではアプリが起動しても何も実行されない。
on open location theURL
	runDiagnosis()
end open location
APPLESCRIPT

# osacompile が作る Contents/Resources/Scripts と衝突しないよう別名にする。
# macOS の標準ファイルシステムは大文字小文字を区別しないため、"scripts" では
# Apple 側の "Scripts" と同じ場所になり main.scpt と混ざってしまう。
mkdir -p "$APP/Contents/Resources/macdoctor"
cp "$ROOT/src/"*.sh "$APP/Contents/Resources/macdoctor/"
chmod +x "$APP/Contents/Resources/macdoctor/"*.sh

# 結果画面の「再診断」ボタンから起動できるよう、専用リンクを登録する。
# ブラウザは他人のMacでプログラムを実行できないが、アプリが登録した専用リンク
# （macshindan://）なら macOS 側が受け取ってアプリを起動できる。
# 署名より前に行うこと。署名後に Info.plist を書き換えると封が破れる。
PLIST="$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleIdentifier string jp.macshindan.diagnostic' "$PLIST" 2>/dev/null || \
  /usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier jp.macshindan.diagnostic' "$PLIST"
/usr/libexec/PlistBuddy -c 'Delete :CFBundleURLTypes' "$PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy \
  -c 'Add :CFBundleURLTypes array' \
  -c 'Add :CFBundleURLTypes:0 dict' \
  -c 'Add :CFBundleURLTypes:0:CFBundleURLName string jp.macshindan.diagnostic' \
  -c 'Add :CFBundleURLTypes:0:CFBundleURLSchemes array' \
  -c 'Add :CFBundleURLTypes:0:CFBundleURLSchemes:0 string macshindan' \
  "$PLIST"

# 中身を入れたあとで必ず署名し直す。
# osacompile は生成時にアドホック署名を付けるが、その後にファイルを足すと
# 封が破れる。破れたままダウンロードされると macOS が「壊れているため開けません。
# ゴミ箱に入れる必要があります」と表示し、右クリックでも起動できなくなる。
codesign --force --deep --sign - "$APP" 2>/dev/null

# 署名が有効でなければビルドを失敗させる。壊れた配布物を出さないための関門。
if ! codesign --verify --deep --strict "$APP" 2>/dev/null; then
  echo "エラー: 署名が壊れています。配布してはいけません。" >&2
  codesign --verify --verbose=4 "$APP" >&2 2>&1 | head -10
  exit 1
fi

# 専用リンクが登録されているか確認する。抜けると再診断ボタンが無反応になる。
if ! /usr/libexec/PlistBuddy -c 'Print :CFBundleURLTypes:0:CFBundleURLSchemes:0' "$PLIST" 2>/dev/null | grep -q '^macshindan$'; then
  echo "エラー: 専用リンク(macshindan://)が登録されていません" >&2
  exit 1
fi

echo "生成しました: $APP（署名の検証: 合格 / 専用リンク: 登録済み）"
