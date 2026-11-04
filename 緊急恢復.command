#!/bin/bash
set -uo pipefail
export PATH=/usr/bin:/bin:/usr/sbin:/sbin
printf '\n=== iMac Solo｜恢復內建螢幕 ===\n'
BIN="$HOME/Applications/iMac Solo.app/Contents/MacOS/iMacSolo"
if [[ ! -x "$BIN" ]]; then BIN="/Applications/iMac Solo.app/Contents/MacOS/iMacSolo"; fi
if [[ -x "$BIN" ]]; then
    "$BIN" --restore
    result=$?
    if [[ $result -ne 0 ]]; then
        printf '\n恢復未確認成功。重新接上外接螢幕後重試；仍失敗時正常重新啟動。\n'
        printf '此工具不會自行強制關機、不會清除設定、不會休眠全部螢幕。\n'
    fi
else
    printf '找不到已安裝的 iMac Solo。請從完整 ZIP 安裝，或使用實際安裝路徑。\n'
    printf '此檔案不會下載任何工具，也不會自動重開機。\n'
fi
if [[ -t 0 ]]; then printf '\n按 Return 結束。'; read -r _ || true; fi
