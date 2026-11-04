#!/bin/bash
set -euo pipefail
export PATH=/usr/bin:/bin:/usr/sbin:/sbin
printf '\n=== iMac Solo｜移除工具 ===\n'
APP="$HOME/Applications/iMac Solo.app"
BIN="$APP/Contents/MacOS/iMacSolo"
if [[ ! -d "$APP" ]]; then echo '使用者 Applications 資料夾沒有這個工具。'; exit 0; fi
if /usr/bin/pgrep -x iMacSolo >/dev/null 2>&1; then
    printf '請先從 iMac Solo 選單選「恢復並結束」，再執行移除。\n'
    printf '為避免中斷安全監控，目前沒有刪除任何東西。\n'
    if [[ -t 0 ]]; then read -r -p '按 Return 結束。' _; fi
    exit 1
fi
if [[ -x "$BIN" ]]; then
    if ! "$BIN" --restore; then
        echo '恢復未確認成功，暫不移除。請先重新接上外接螢幕並恢復畫面。'
        if [[ -t 0 ]]; then read -r -p '按 Return 結束。' _; fi
        exit 1
    fi
fi
read -r -p '將 iMac Solo 移至垃圾桶？輸入 y 確認：' answer
if [[ "$answer" != y && "$answer" != Y ]]; then echo '已取消。'; exit 0; fi
/bin/mkdir -p "$HOME/.Trash"
/bin/mv "$APP" "$HOME/.Trash/iMac Solo-$('/bin/date' +%Y%m%d-%H%M%S)-$$.app"
printf '\n已移至垃圾桶。沒有安裝系統服務或登入自啟動項目。\n'
printf '記錄保留於 ~/Library/Application Support/iMacSolo，可自行移至垃圾桶。\n'
if [[ -t 0 ]]; then read -r -p '按 Return 結束。' _; fi
