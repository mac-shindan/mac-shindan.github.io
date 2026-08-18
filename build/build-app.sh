#!/bin/bash
# 配布用の Mac診断.app を生成する。macOS標準の osacompile のみを使う。
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/Mac診断.app"

rm -rf "$APP"

# path to me でアプリ自身の場所を得て、同梱したシェルスクリプトを実行する。
# do shell script はターミナルを開かない。
osacompile -o "$APP" <<'APPLESCRIPT'
set myPath to POSIX path of (path to me)
set runner to quoted form of (myPath & "Contents/Resources/macdoctor/mac-doctor.sh")
try
	do shell script "/bin/bash " & runner
on error errMsg
	display dialog "診断中に問題が発生しました。情シスに次の内容を伝えてください：" & return & return & errMsg buttons {"OK"} default button "OK" with icon caution
end try
APPLESCRIPT

# osacompile が作る Contents/Resources/Scripts と衝突しないよう別名にする。
# macOS の標準ファイルシステムは大文字小文字を区別しないため、"scripts" では
# Apple 側の "Scripts" と同じ場所になり main.scpt と混ざってしまう。
mkdir -p "$APP/Contents/Resources/macdoctor"
cp "$ROOT/src/"*.sh "$APP/Contents/Resources/macdoctor/"
chmod +x "$APP/Contents/Resources/macdoctor/"*.sh

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

echo "生成しました: $APP（署名の検証: 合格）"
