#!/bin/bash
# SPDX-License-Identifier: MIT
# Explicitly-confirmed, source-only GitHub publication helper. No secrets are collected by this script.
set -euo pipefail
umask 077
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
ROOT="$(cd -- "$(dirname -- "$0")" && pwd -P)"
cd "$ROOT"

pause_on_exit() {
  exit_code="$1"
  if [[ "$exit_code" -ne 0 ]]; then
    printf '\n發布未完成（代碼 %s）。本工具未嘗試關閉顯示器。\n' "$exit_code"
  fi
  if [[ -t 0 ]]; then
    printf '\n按 Return 關閉此視窗…'
    read -r _ || true
  fi
}
trap 'code=$?; pause_on_exit "$code"' EXIT

printf '\n=== iMac Solo｜公開到 GitHub（原始碼實驗版）===\n\n'
printf '這將建立「公開」儲存庫，任何人都能下載你的程式碼與歷史記錄。\n'
printf '尚無 iMac M1 + macOS 27 實機驗證，也未完成第三方完整源碼相似度比對。\n'
printf '本流程不會發布 .app/.dmg，不會停用螢幕，也不會要求你輸入 GitHub Token。\n\n'

if [[ "$(uname -s)" != "Darwin" ]]; then
  printf '請在 macOS 上執行此工具。\n'
  exit 1
fi
for tool in git gh python3 shasum; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    printf '缺少 %s。請先安裝，然後重新執行。\n' "$tool"
    if [[ "$tool" == gh ]]; then
      printf 'GitHub CLI 官網：https://cli.github.com/\n'
      printf '注意：ChatGPT 的 GitHub 連線不等於這台 Mac 安裝了 gh CLI。\n'
    fi
    exit 1
  fi
done

if ! gh auth status >/dev/null 2>&1; then
  printf 'GitHub CLI 尚未登入，請先在 Terminal 執行 gh auth login 完成瀏覽器登入。\n'
  exit 1
fi
if [[ -z "$(git config user.name || true)" || -z "$(git config user.email || true)" ]]; then
  printf 'Git 尚未設定提交者名稱／Email。請先設定 git config user.name 與 user.email。\n'
  printf '若要保護個人信箱，可使用 GitHub 設定頁提供的 noreply Email。\n'
  exit 1
fi

printf '[1/4] 驗證下載的原始碼與文件完整性…\n'
shasum -a 256 -c SHA256SUMS.txt >/dev/null
python3 Tests/audit.py
for f in ./*.command; do bash -n "$f"; done

printf '\n[2/4] 驗證 macOS Swift SDK 可用並嘗試完整編譯（不執行程式）…\n'
if ! command -v xcrun >/dev/null 2>&1; then
  printf '找不到 Apple Command Line Tools，請先執行 xcode-select --install。\n'
  exit 1
fi
TMP="$(mktemp -d "${TMPDIR:-/tmp}/imacsolo-github.XXXXXX")"
trap 'code=$?; rm -rf -- "$TMP"; pause_on_exit "$code"' EXIT
xcrun swiftc -swift-version 5 Sources/Policy.swift Tests/main.swift -o "$TMP/policy-tests"
"$TMP/policy-tests"
xcrun swiftc -swift-version 5 -O -target arm64-apple-macos13.0 \
  Sources/Policy.swift Sources/DisplayBridge.swift Sources/Guardian.swift \
  Sources/App.swift Sources/main.swift \
  -framework AppKit -framework CoreGraphics -o "$TMP/iMacSolo"

printf '\n[3/4] 公開內容確認…\n'
REPO_NAME='iMac-Solo'
REPO_OWNER="$(gh api user --jq .login)"
if [[ -z "$REPO_OWNER" ]]; then printf '無法取得 GitHub 登入帳號。\n'; exit 1; fi
printf '預定儲存庫：%s/%s\n' "$REPO_OWNER" "$REPO_NAME"
printf '請確認 README、LICENSE、THIRD_PARTY_NOTICES.md 與 docs/LICENSE_AUDIT.md 已看過。\n'
printf '如你需要更改版權署名，請先編輯檔案、重新產生 SHA256SUMS，再執行本工具。\n'
printf '輸入 PUBLIC 才會將整個專案公開：'
read -r CONFIRM
if [[ "$CONFIRM" != 'PUBLIC' ]]; then
  printf '已取消。沒有建立儲存庫。\n'
  exit 0
fi

if [[ -d .git ]]; then
  if git remote get-url origin >/dev/null 2>&1; then
    printf '已存在 origin remote；為避免上傳到錯誤位置，請檢查後手動推送。\n'
    exit 1
  fi
else
  git init -b main
fi
if gh repo view "$REPO_OWNER/$REPO_NAME" >/dev/null 2>&1; then
  printf '你的 GitHub 帳號已有名為 %s 的儲存庫；不自動覆寫。\n' "$REPO_NAME"
  exit 1
fi

git add -A
if git diff --cached --name-only | grep -E '(^|/)(\.env|[^/]*\.pem|[^/]*\.p12|[^/]*\.key|[^/]*token[^/]*)$' >/dev/null; then
  printf '偵測到可能的機密檔案；已停止提交。\n'
  exit 1
fi
git diff --cached --check
if ! git diff --cached --quiet; then
  git commit -m 'Initial experimental source release with license audit'
fi

printf '\n[4/4] 建立公開 GitHub 儲存庫並上傳 main…\n'
gh repo create "$REPO_OWNER/$REPO_NAME" --public --source . --remote origin --push
printf '\n完成。請至 GitHub 核對 repository 已設為 Public，並查看 Actions 編譯結果。\n'
gh repo view --web || true
