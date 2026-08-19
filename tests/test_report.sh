#!/bin/bash
. "$(cd "$(dirname "$0")" && pwd)/run.sh"

TSV=$(mktemp); ENVF="$TEST_DIR/fixtures/memory_pressure.env"
bash "$SRC_DIR/judge.sh" < "$ENVF" > "$TSV"
HTML=$(bash "$SRC_DIR/report.sh" "$TSV" "$ENVF" 2>/dev/null)

echo "== 外部参照が0件である =="
n_ext=$(printf '%s\n' "$HTML" | grep -cE 'https?://|src="//|href="//' || true)
assert_eq "外部URLを含まない" 0 "$n_ext"

echo "== 必要な内容が含まれる =="
for needle in "要対応" "スワップ" "モニタ接続方式" "ケーブル" "結果をコピー" "MacBook Air" \
              "体感" "ほぼ 0" "目安です"; do
  if printf '%s\n' "$HTML" | grep -q "$needle"; then
    PASSED=$((PASSED+1)); printf '  ok   "%s" を含む\n' "$needle"
  else
    FAILED=$((FAILED+1)); printf '  FAIL "%s" を含まない\n' "$needle"
  fi
done

echo "== 正常な項目は折りたたまれる =="
if printf '%s\n' "$HTML" | grep -q '<details'; then
  PASSED=$((PASSED+1)); printf '  ok   details要素がある\n'
else
  FAILED=$((FAILED+1)); printf '  FAIL details要素がない\n'
fi

echo "== メモリ上位アプリの表示 =="
for needle in "メモリを多く使っているアプリ" "Google Chrome" "閉じるならこの順番"; do
  if printf '%s\n' "$HTML" | grep -q "$needle"; then
    PASSED=$((PASSED+1)); printf '  ok   "%s" を含む\n' "$needle"
  else
    FAILED=$((FAILED+1)); printf '  FAIL "%s" を含まない\n' "$needle"
  fi
done

echo "== 再起動直後は再起動を勧めない（画面上でも） =="
TSV2=$(mktemp); ENV2="$TEST_DIR/fixtures/fresh_boot_pressure.env"
bash "$SRC_DIR/judge.sh" < "$ENV2" > "$TSV2"
HTML2=$(bash "$SRC_DIR/report.sh" "$TSV2" "$ENV2" 2>/dev/null)
if printf '%s\n' "$HTML2" | grep -q 'Macを再起動してください'; then
  FAILED=$((FAILED+1)); printf '  FAIL 再起動を勧めている\n'
else
  PASSED=$((PASSED+1)); printf '  ok   再起動を勧めていない\n'
fi
rm -f "$TSV2"

echo "== 再診断ボタン =="
for needle in 'href="macshindan://run"' 'もう一度診断する' 'Dock の Mac診断'; do
  if printf '%s\n' "$HTML" | grep -qF "$needle"; then
    PASSED=$((PASSED+1)); printf '  ok   "%s" を含む\n' "$needle"
  else
    FAILED=$((FAILED+1)); printf '  FAIL "%s" を含まない\n' "$needle"
  fi
done

echo "== 判定の根拠としてモニタ一覧を表示する =="
for needle in "接続中のモニタ" "EX-LDH241DB" "接続方式は取得できません"; do
  if printf '%s\n' "$HTML" | grep -qF "$needle"; then
    PASSED=$((PASSED+1)); printf '  ok   "%s" を含む\n' "$needle"
  else
    FAILED=$((FAILED+1)); printf '  FAIL "%s" を含まない\n' "$needle"
  fi
done

echo "== 不明な接続方式をDisplayLinkと断定しない =="
if printf '%s\n' "$HTML" | grep -qF '>DisplayLink</span>'; then
  FAILED=$((FAILED+1)); printf '  FAIL モニタ一覧でDisplayLinkと断定している\n'
else
  PASSED=$((PASSED+1)); printf '  ok   断定していない\n'
fi

rm -f "$TSV"
finish
