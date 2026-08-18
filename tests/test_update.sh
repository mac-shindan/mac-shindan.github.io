#!/bin/bash
# update.sh の分岐を検証する。実際の配布サイトには接続せず、
# ローカルのファイルURLを差し込んで確認する。
. "$(cd "$(dirname "$0")" && pwd)/run.sh"

SB=$(mktemp -d)
DEST="$SB/home/Applications/Mac診断.app"
mkdir -p "$DEST/Contents/Resources/macdoctor"
printf 'old-id\n' > "$DEST/Contents/Resources/macdoctor/BUILD_ID"

# 配布側の擬似ファイル
mkdir -p "$SB/site/x/Mac診断.app/Contents/Resources/macdoctor"
printf 'new-id\n' > "$SB/site/x/Mac診断.app/Contents/Resources/macdoctor/BUILD_ID"
printf 'new-id\n' > "$SB/site/BUILD_ID"
printf 'old-id\n' > "$SB/site/BUILD_ID_SAME"
( cd "$SB/site/x" && ditto -c -k --sequesterRsrc --keepParent "Mac診断.app" "$SB/site/app.zip" )

run_update() { # $1=公開側の指紋ファイル
  HOME="$SB/home" \
  MACDOCTOR_ID_URL="file://$SB/site/$1" \
  MACDOCTOR_ZIP_URL="file://$SB/site/app.zip" \
    bash "$SRC_DIR/update.sh" 2>/dev/null
}

echo "== 同じ版なら何もしない =="
assert_eq "指紋が同じなら更新しない" "" "$(run_update BUILD_ID_SAME)"

echo "== 新しい版があれば入れ替えを予約する =="
OUT=$(run_update BUILD_ID)
case "$OUT" in
  update-scheduled:*) PASSED=$((PASSED+1)); printf '  ok   更新を予約した\n' ;;
  *) FAILED=$((FAILED+1)); printf '  FAIL 更新されない (出力: %s)\n' "${OUT:-空}" ;;
esac

echo "== 予約から実際に入れ替わる =="
for i in 1 2 3 4 5 6 7 8 9 10 11 12; do
  /bin/sleep 2
  [ "$(cat "$DEST/Contents/Resources/macdoctor/BUILD_ID" 2>/dev/null)" = "new-id" ] && break
done
assert_eq "アプリが新しい版になった" "new-id" "$(cat "$DEST/Contents/Resources/macdoctor/BUILD_ID" 2>/dev/null)"

echo "== 未設置なら何もしない =="
rm -rf "$DEST"
assert_eq "未設置では更新しない" "" "$(run_update BUILD_ID)"

rm -rf "$SB"
finish
