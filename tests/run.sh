#!/bin/bash
# 簡易テストランナー。assert 関数を提供し、失敗数を数える。
set -u
TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_DIR="$TEST_DIR/../src"
FAILED=0
PASSED=0

# fixture を judge.sh に流し、指定 check_id の status が期待どおりか検証する
# 使い方: assert_status <fixture名> <check_id> <期待status>
assert_status() {
  fixture="$1"; check_id="$2"; want="$3"
  got=$(bash "$SRC_DIR/judge.sh" < "$TEST_DIR/fixtures/$fixture" 2>/dev/null \
        | awk -F'\t' -v id="$check_id" '$1==id{print $4}')
  if [ "$got" = "$want" ]; then
    PASSED=$((PASSED+1))
    printf '  ok   %-22s %-14s = %s\n' "$fixture" "$check_id" "$got"
  else
    FAILED=$((FAILED+1))
    printf '  FAIL %-22s %-14s want=%s got=%s\n' "$fixture" "$check_id" "$want" "${got:-<出力なし>}"
  fi
}

# fixture を judge.sh に流し、出力全体に文字列が含まれるか検証する
assert_contains() {
  fixture="$1"; needle="$2"
  if bash "$SRC_DIR/judge.sh" < "$TEST_DIR/fixtures/$fixture" 2>/dev/null | grep -q "$needle"; then
    PASSED=$((PASSED+1)); printf '  ok   %-22s contains "%s"\n' "$fixture" "$needle"
  else
    FAILED=$((FAILED+1)); printf '  FAIL %-22s contains "%s"\n' "$fixture" "$needle"
  fi
}

# 任意のコマンドの標準出力が期待値と一致するか検証する
assert_eq() {
  label="$1"; want="$2"; got="$3"
  if [ "$got" = "$want" ]; then
    PASSED=$((PASSED+1)); printf '  ok   %s\n' "$label"
  else
    FAILED=$((FAILED+1)); printf '  FAIL %s  want=%s got=%s\n' "$label" "$want" "$got"
  fi
}

finish() {
  echo
  echo "  合格 $PASSED / 失敗 $FAILED"
  [ "$FAILED" -eq 0 ] || exit 1
  exit 0
}
