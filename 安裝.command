#!/bin/bash
set -euo pipefail
umask 077
export PATH=/usr/bin:/bin:/usr/sbin:/sbin
HERE="$(cd -- "$(dirname -- "$0")" && pwd -P)"
BUILD=""
finish() {
    code=$?
    if [[ -n "$BUILD" && -d "$BUILD" ]]; then /bin/rm -rf -- "$BUILD"; fi
    if [[ $code -ne 0 ]]; then
        printf '\n安裝未完成（代碼 %s）。請保留上方錯誤訊息；未停用任何螢幕。\n' "$code"
    fi
    if [[ -t 0 ]]; then printf '\n按 Return 結束此安裝視窗。'; read -r _ || true; fi
}
trap finish EXIT
printf '\n=== iMac Solo 0.1.0｜本機建置安裝包 ===\n\n'
printf '尚未在 iMac M1 + macOS 27 實機驗證。此安裝流程不會停用螢幕。\n'
printf '不需要付費授權、Homebrew、sudo，亦不會停用系統安全機制。\n\n'
[[ "$(/usr/bin/uname -s)" == Darwin ]] || { echo '只能在 Mac 上執行。'; exit 1; }
[[ "$(/usr/sbin/sysctl -n hw.optional.arm64 2>/dev/null || true)" == 1 ]] || {
    echo '此建置包針對 Apple Silicon；未偵測到相容晶片。'; exit 1;
}
OS_MAJOR="$(/usr/bin/sw_vers -productVersion | /usr/bin/cut -d . -f 1)"
[[ "$OS_MAJOR" -ge 13 ]] || { echo '需要 macOS 13 或更新版本。'; exit 1; }
if /usr/bin/pgrep -x iMacSolo >/dev/null 2>&1; then
    echo '請先在 iMac Solo 選單選「恢復並結束」，再重新安裝。'; exit 1
fi
cd "$HERE"
[[ -f Sources/main.swift && -f SHA256SUMS.txt ]] || {
    echo '請先完整解壓縮 ZIP，不要只取出安裝.command。'; exit 1
}
/usr/bin/shasum -a 256 -c SHA256SUMS.txt > /dev/null || {
    echo '封裝內容校驗失敗。請重新下載完整 ZIP；安裝已停止。'; exit 1
}
if ! /usr/bin/xcode-select -p >/dev/null 2>&1; then
    printf '\n這台 Mac 尚未安裝 Apple Command Line Tools。\n'
    printf '接下來會打開 Apple 官方安裝視窗；完成後重新執行本檔案。\n'
    printf '不必安裝完整 Xcode。Apple 安裝程序可能要求系統授權及網路連線。\n'
    /usr/bin/xcode-select --install || true
    exit 0
fi
if ! /usr/bin/xcrun --find swiftc >/dev/null 2>&1; then
    echo '找不到 Swift 編譯器。請在系統設定的軟體更新安裝相容的 Command Line Tools。'; exit 1
fi
BUILD="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/imacsolo.XXXXXX")"
LOG="$HERE/安裝記錄.log"
{
    echo 'iMac Solo build log'
    /usr/bin/sw_vers
    /usr/bin/xcrun swiftc --version
} > "$LOG"
printf '\n[1/4] 執行不碰顯示器的安全規則測試…\n'
/usr/bin/xcrun swiftc -swift-version 5 Sources/Policy.swift Tests/main.swift -o "$BUILD/policy-tests" 2>&1 | /usr/bin/tee -a "$LOG"
"$BUILD/policy-tests" 2>&1 | /usr/bin/tee -a "$LOG"
printf '\n[2/4] 在你的 Mac 上建置原生應用程式…\n'
APP="$BUILD/iMac Solo.app"
/bin/mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
/usr/bin/xcrun swiftc -swift-version 5 -O -target arm64-apple-macos13.0 \
    Sources/Policy.swift Sources/DisplayBridge.swift Sources/Guardian.swift Sources/App.swift Sources/main.swift \
    -framework AppKit -framework CoreGraphics -o "$APP/Contents/MacOS/iMacSolo" 2>&1 | /usr/bin/tee -a "$LOG"
/bin/cp "$HERE/Info.plist" "$APP/Contents/Info.plist"
/bin/cp "$HERE/使用說明.html" "$APP/Contents/Resources/Guide.html"
/bin/cp "$HERE/LICENSE.txt" "$APP/Contents/Resources/LICENSE.txt"
/usr/bin/plutil -lint "$APP/Contents/Info.plist" | /usr/bin/tee -a "$LOG"
printf '\n[3/4] 本機臨時簽章（不是 Apple 公證）…\n'
/usr/bin/codesign --force --sign - --timestamp=none "$APP" 2>&1 | /usr/bin/tee -a "$LOG"
/usr/bin/codesign --verify --strict "$APP" 2>&1 | /usr/bin/tee -a "$LOG"
printf '\n[4/4] 安裝到你的使用者 Applications 資料夾…\n'
/bin/mkdir -p "$HOME/Applications"
DEST="$HOME/Applications/iMac Solo.app"
if [[ -e "$DEST" ]]; then
    BACKUP="$HOME/Applications/iMac Solo.previous.$(/bin/date +%Y%m%d-%H%M%S).$$.app"
    /bin/mv "$DEST" "$BACKUP"
    printf '舊版本已保留為：%s\n' "$BACKUP"
fi
/bin/mv "$APP" "$DEST"
printf '\n安裝完成：%s\n' "$DEST"
printf '初次測試：接好 HDMI → 按「測試 20 秒」→ 在外接螢幕確認。\n'
printf '未點擊測試前，程式不會關閉任何螢幕。\n'
/usr/bin/open "$DEST"
