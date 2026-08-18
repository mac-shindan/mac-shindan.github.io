#!/bin/bash
# install.sh の分岐を検証する。ダイアログは MACDOCTOR_INSTALL_ANSWER で差し替える。
# 実際の ~/Applications を汚さないよう HOME を一時ディレクトリに向ける。
. "$(cd "$(dirname "$0")" && pwd)/run.sh"

SANDBOX=$(mktemp -d)
FAKE_APP="$SANDBOX/src/Mac診断.app"
mkdir -p "$FAKE_APP/Contents/Resources/macdoctor"
printf 'dummy\n' > "$FAKE_APP/Contents/Resources/macdoctor/mac-doctor.sh"

run_install() { # $1=引数 $2=応答 → 標準出力
  HOME="$SANDBOX/home" MACDOCTOR_INSTALL_ANSWER="$2" \
    bash "$SRC_DIR/install.sh" "$1" 2>/dev/null
}

echo "== .app 以外を渡したら何もしない =="
assert_eq "ソース実行では設置しない" "" "$(run_install "$SANDBOX/src" 追加する)"

echo "== 存在しないパスでは何もしない =="
assert_eq "不在パスでは設置しない" "" "$(run_install "$SANDBOX/nope.app" 追加する)"

echo "== 「あとで」なら設置しない =="
assert_eq "あとでを選ぶと設置しない" "" "$(run_install "$FAKE_APP" あとで)"
if [ ! -e "$SANDBOX/home/Applications/Mac診断.app" ]; then
  PASSED=$((PASSED+1)); printf '  ok   設置先が作られていない\n'
else
  FAILED=$((FAILED+1)); printf '  FAIL 設置されてしまった\n'
fi

echo "== 「追加する」なら設置する =="
OUT=$(run_install "$FAKE_APP" 追加する)
case "$OUT" in
  installed:*) PASSED=$((PASSED+1)); printf '  ok   設置を報告する\n' ;;
  *) FAILED=$((FAILED+1)); printf '  FAIL 設置を報告しない (出力: %s)\n' "${OUT:-空}" ;;
esac
if [ -f "$SANDBOX/home/Applications/Mac診断.app/Contents/Resources/macdoctor/mac-doctor.sh" ]; then
  PASSED=$((PASSED+1)); printf '  ok   中身ごとコピーされている\n'
else
  FAILED=$((FAILED+1)); printf '  FAIL コピーされていない\n'
fi

echo "== 2回目は何もしない（二重設置しない） =="
assert_eq "設置済みなら再設置しない" "" "$(run_install "$FAKE_APP" 追加する)"

rm -rf "$SANDBOX"
finish
