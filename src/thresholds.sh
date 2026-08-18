#!/bin/bash
# 判定閾値の定義。判定基準の調整はこのファイルだけを変更する。
# 実測値を見て調整する前提の初期値。

# メモリ空き率 (%) — これ未満で該当
TH_FREE_PCT_WARN=30
TH_FREE_PCT_NG=10

# スワップ使用量 (MB) — これ以上で該当
TH_SWAP_WARN=512
TH_SWAP_NG=2048

# 圧縮メモリ (GB) — これ以上で該当
TH_COMPRESSED_WARN=4
TH_COMPRESSED_NG=8

# WindowServer の CPU 使用率 (%) — これ以上で該当
TH_WS_WARN=10
TH_WS_NG=25

# 熱スロットリング (CPU_Speed_Limit %) — これ未満で該当
TH_THERM_WARN=100
TH_THERM_NG=70

# プロセス数 — これ以上で該当
TH_CHROME_WARN=30
TH_CHROME_NG=60
TH_NODE_WARN=10
TH_NODE_NG=30
TH_CLAUDE_WARN=5
TH_CLAUDE_NG=10

# 未再起動日数 — これ以上で該当
TH_UPTIME_WARN=7
TH_UPTIME_NG=14
