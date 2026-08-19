#!/bin/bash
. "$(cd "$(dirname "$0")" && pwd)/run.sh"

echo "== スワップ判定 =="
assert_status healthy.env          swap OK
assert_status memory_pressure.env  swap NG

echo "== メモリ空き率 =="
assert_status healthy.env          free_pct OK
assert_status memory_pressure.env  free_pct OK

echo "== 圧縮メモリ =="
assert_status healthy.env          compressed OK
assert_status memory_pressure.env  compressed NG

echo "== モニタ接続方式 =="
assert_status healthy.env          display_link OK
assert_status memory_pressure.env  display_link NG
# 機器が無くソフトだけ残っている場合は重さの原因ではないため OK。
# 以前はソフトの常駐だけで注意扱いにしていたが、誤解を招くため改めた。
assert_status displaylink_idle.env display_link OK
# 上限に余裕があるケース（外部1枚・直接扱えるのも1枚）でケーブル交換を案内する。
# memory_pressure は外部2枚で上限超えのため、案内内容が異なるのが正しい。
assert_contains single_dl_monitor.env "ケーブル"

echo "== WindowServer 負荷 =="
assert_status healthy.env          windowserver OK
assert_status memory_pressure.env  windowserver NG

echo "== 熱スロットリング =="
assert_status healthy.env          thermal OK
assert_status thermal_air.env      thermal NG
assert_status memory_pressure.env  thermal UNKNOWN

echo "== プロセス過多 =="
assert_status healthy.env          processes OK
assert_status memory_pressure.env  processes NG
assert_status thermal_air.env      processes OK

echo "== 未再起動日数 =="
assert_status healthy.env          uptime OK
assert_status memory_pressure.env  uptime WARN

echo "== 出力の完全性 =="
for f in healthy memory_pressure displaylink_idle thermal_air fresh_boot_pressure dl_installed_not_used single_dl_monitor plain_hub_no_dl at_native_limit; do
  n=$(bash "$SRC_DIR/judge.sh" < "$TEST_DIR/fixtures/$f.env" | wc -l | tr -d ' ')
  assert_eq "$f.env は8項目を出力する" 8 "$n"
  cols=$(bash "$SRC_DIR/judge.sh" < "$TEST_DIR/fixtures/$f.env" | awk -F'\t' '{print NF}' | sort -u | tr '\n' ' ')
  assert_eq "$f.env は全行10列である" "10 " "$cols"
done

echo "== 改善予測 =="
# NG / WARN には必ず予測と体感度が入り、OK / UNKNOWN には入らないことを固定する。
for f in healthy memory_pressure displaylink_idle thermal_air fresh_boot_pressure dl_installed_not_used single_dl_monitor plain_hub_no_dl at_native_limit; do
  bad_missing=$(bash "$SRC_DIR/judge.sh" < "$TEST_DIR/fixtures/$f.env" \
    | awk -F'\t' '($4=="NG"||$4=="WARN") && ($9=="-"||$9==""||$10=="-"||$10=="")' | wc -l | tr -d ' ')
  assert_eq "$f.env: NG/WARN に予測がある" 0 "$bad_missing"
  ok_filled=$(bash "$SRC_DIR/judge.sh" < "$TEST_DIR/fixtures/$f.env" \
    | awk -F'\t' '($4=="OK"||$4=="UNKNOWN") && $9!="-"' | wc -l | tr -d ' ')
  assert_eq "$f.env: OK/UNKNOWN に予測がない" 0 "$ok_filled"
done

echo "== 予測が実測値を使っている =="
assert_contains memory_pressure.env "20.5GB → ほぼ 0"
assert_contains thermal_air.env     "55% → 100%"

echo "== 再起動直後のメモリ逼迫は「再起動」を勧めない =="
# 起動3時間でスワップ5GBという実機の状況。ここで再起動を勧めるのは誤案内。
assert_status  fresh_boot_pressure.env swap NG
assert_status  fresh_boot_pressure.env compressed WARN
assert_contains fresh_boot_pressure.env "Google Chrome"
if bash "$SRC_DIR/judge.sh" < "$TEST_DIR/fixtures/fresh_boot_pressure.env" \
   | awk -F'\t' '$1=="swap"||$1=="compressed"' | grep -q '再起動してください'; then
  FAILED=$((FAILED+1)); printf '  FAIL 再起動直後なのに再起動を勧めている\n'
else
  PASSED=$((PASSED+1)); printf '  ok   再起動を勧めていない\n'
fi

echo "== 長期間再起動していない場合は「再起動」を勧める =="
if bash "$SRC_DIR/judge.sh" < "$TEST_DIR/fixtures/memory_pressure.env" \
   | awk -F'\t' '$1=="compressed"' | grep -q '再起動'; then
  PASSED=$((PASSED+1)); printf '  ok   再起動を勧めている\n'
else
  FAILED=$((FAILED+1)); printf '  FAIL 長期稼働なのに再起動を勧めていない\n'
fi

echo "== 閉じるべきアプリ名を示す =="
assert_contains memory_pressure.env "Google Chrome"

echo "== DisplayLinkが入っているだけで使っていない場合は誤判定しない =="
# ソフトは常駐しているが、モニタ2枚は DisplayPort で直結されているケース。
# 以前はこれを 🔴 と誤判定していた（実際に報告があった）。
assert_status  dl_installed_not_used.env display_link OK
assert_contains dl_installed_not_used.env "直結"

echo "== 実際にDisplayLink経由なら従来どおり検出する =="
assert_status memory_pressure.env display_link NG

echo "== DisplayLinkが原因なら「枚数を減らせ」と言わない =="
# 外部1枚のみ。直結すれば解決するのに枚数を減らすよう案内するのは誤り。
assert_status  single_dl_monitor.env windowserver WARN
assert_contains single_dl_monitor.env "枚数を減らす必要はありません"
if bash "$SRC_DIR/judge.sh" < "$TEST_DIR/fixtures/single_dl_monitor.env" \
   | awk -F'\t' '$1=="windowserver"' | grep -q 'モニタの枚数を減らすと軽くなります'; then
  FAILED=$((FAILED+1)); printf '  FAIL 枚数を減らすよう案内している\n'
else
  PASSED=$((PASSED+1)); printf '  ok   直結を案内している\n'
fi

echo "== DisplayLink機器が繋がっていなければ🔴にしない =="
# 従業員の実機: 1枚は直結、1枚は普通のハブ経由。DisplayLink機器は無い。
# 接続方式が取得できないだけで DisplayLink と断定してはいけない。
assert_status plain_hub_no_dl.env display_link OK

echo "== DisplayLink機器が繋がっていれば🔴にし、製品名を示す =="
assert_status  memory_pressure.env display_link NG
assert_contains memory_pressure.env "USB3.0 5K Graphic Docking"

echo "== 直結の上限に達している場合は不可能な案内をしない =="
# 外部2枚・直接扱えるのは1枚のMac。1枚は既に直結済みで、これ以上は改善不可。
assert_contains at_native_limit.env "1枚"
if bash "$SRC_DIR/judge.sh" < "$TEST_DIR/fixtures/at_native_limit.env" \
   | awk -F'\t' '$1=="display_link"{print $9}' | grep -q '5%前後'; then
  FAILED=$((FAILED+1)); printf '  FAIL 達成できない改善見込みを出している\n'
else
  PASSED=$((PASSED+1)); printf '  ok   達成できない見込みを出していない\n'
fi

echo "== 上限に余裕があれば従来どおり直結を勧める =="
assert_contains memory_pressure.env "直結してください"

finish
