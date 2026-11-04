# iMac Solo · iMac 內建顯示器軟體中斷工具

**Experimental source release / 實驗性原始碼發布 · v0.1.0**

iMac Solo 是一款繁體中文 macOS 選單列工具，旨在讓使用者在**外接實體螢幕仍運作**的情況下，要求 macOS 將 iMac 內建顯示器移出線上桌面。它**不是**黑色遮罩、黑桌布或單純降低亮度。工具內含 20 秒操作確認、獨立安全監控程序、恢復指令及本機建置腳本。

> **未完成實機驗證**：已執行 53 項平台無關的安全規則測試、Swift 語法解析與腳本／封裝靜態檢查，但**沒有在 macOS SDK 完整建置**，也**沒有在 iMac M1 + macOS 27 + USB-C 轉 HDMI** 完成實機測試。請勿將本專案描述為已驗證、穩定或能保證恢復。

## 下載與安裝

此 repository 提供**原始碼**，尚無 Developer ID 簽章、公證或硬體驗證過的 `.app`。請先保存工作、接好 HDMI 並使用延伸桌面，再在 Apple Silicon Mac 上：

1. 使用 GitHub `Code → Download ZIP` 取得完整專案（或 `git clone`）。
2. 解壓縮後閱讀 [`先讀我.md`](先讀我.md)／[`使用說明.html`](使用說明.html)。
3. 在 Mac 上執行 `安裝.command`；缺少 Apple Command Line Tools 時會先要求你安裝。
4. 建置成功後，App 位於 `~/Applications/iMac Solo.app`。
5. 接好外接顯示器、確認控制視窗真的在外接螢幕，再手動執行**20 秒測試**。僅當 HDMI 畫面可用且內建面板沒有可見背光時，才按下保留。

如雙擊 `.command` 沒有執行，可在終端機輸入 `/bin/bash `（尾端空白），把 `安裝.command` 拖入終端機後按 Return。**不要停用 SIP、Gatekeeper 或其他系統安全機制。**

## 發布到 GitHub（公開原始碼）

如果希望公開這個實驗專案，內附 [`發布到GitHub.command`](發布到GitHub.command)。在你的 Mac 上先安裝 [GitHub CLI](https://cli.github.com/) 並執行 `gh auth login`，然後雙擊該檔案。它會先驗證檔案、執行政策測試並**嘗試完成 macOS SDK 編譯**，只有你輸入 `PUBLIC` 才會建立公開儲存庫並上傳 `main`。這個腳本不收集 GitHub Token，且不會發布未測試的 `.app` 或 `.dmg`。

**提醒：** ChatGPT 的 GitHub 外掛連線與 Mac 上的 `gh` 命令列登入是兩回事。詳見 [`docs/PUBLISHING.md`](docs/PUBLISHING.md)。

## 功能邊界與安全

- 使用 Apple **非公開** `CGSGetDisplayList`／`CGSConfigureDisplayEnabled`，透過動態符號查找，不保證每版 macOS 支援。
- 設定只提交到目前使用者工作階段，不改 NVRAM，不要求 root，也沒有永久關閉或自動重新關閉機制。
- 守護程序會在倒數逾時、控制視窗程序失去回應或外接螢幕失去連線等情況下**嘗試**恢復，但無法保證每種故障都能復原。
- 軟體判定顯示器「離線」**不代表**已證明面板電源完全斷電；背光必須人工目視確認。
- 開機、FileVault 解鎖、登入、睡眠與 WindowServer 異常可能造成額外風險。
- 需要救援時，先保持外接螢幕可用，執行 `緊急恢復.command`；若系統仍能操作可嘗試正常重新開機。
- 工具沒有網路遙測、第三方登入、內嵌分析 SDK；但 Apple Command Line Tools 首次安裝可能需要連線。

## 專案結構

| 路徑 | 內容 |
|---|---|
| `Sources/` | Swift AppKit GUI、顯示器橋接、守護程序、安全政策 |
| `Tests/` | 53 項平台無關的安全政策測試與靜態檢查 |
| `安裝.command` | Apple Silicon Mac 上本機編譯及安裝 |
| `緊急恢復.command` | 只嘗試重新啟用內建顯示器 |
| `docs/LICENSE_AUDIT.md` | 第三方來源、授權與未決風險檢查報告 |
| `THIRD_PARTY_NOTICES.md` | 技術參考、未封裝的第三方專案及來源註記 |
| `docs/PUBLISHING.md` | GitHub 發布及版本標示檢查表 |

## 自動化檢查（不會關閉螢幕）

```bash
swiftc -swift-version 5 Sources/Policy.swift Tests/main.swift -o /tmp/imacsolo-policy-tests
/tmp/imacsolo-policy-tests
swiftc -frontend -parse Sources/*.swift
python3 Tests/audit.py
for f in ./*.command; do bash -n "$f"; done
```

GitHub Actions 在 macOS runner 中另嘗試完整編譯；**CI 編譯成功不代表硬體操作安全或背光確實關閉**。

## 開源授權、來源與 AI 協作聲明

此儲存庫以 [`MIT`](LICENSE) 授權發行其中有權授權的內容；保留版權聲明及授權文字即可依條件使用。此版沒有封裝其他專案的二進位檔、第三方字型、影像或程式套件。

技術上曾參考 [zy0816/ScreenOff](https://github.com/zy0816/ScreenOff)（[MIT](https://github.com/zy0816/ScreenOff/blob/main/LICENSE)）與 [jjongkwann/MacDisplay](https://github.com/jjongkwann/MacDisplay)（[MIT](https://github.com/jjongkwann/MacDisplay/blob/main/LICENSE)；其授權文件另致謝 DisplayDeck），以及 Apple 的系統框架文件。**兩個專案的 LICENSE 原文已核對；仍未完成所有相關程式碼的逐行相似度／衍生作品鑑別，不能保證零著作權風險。** 來源與審查限制詳見 [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) 與 [`docs/LICENSE_AUDIT.md`](docs/LICENSE_AUDIT.md)。

專案內容由 AI 助手依使用者需求協助撰寫與封裝；本次授權審查是技術文件審查，**不是法律意見，亦不能證明與所有現存專案不存在相似程式碼**。欲對外發行前，維護者應審查程式碼、確認權利及進行 Mac 實機測試。

## 非官方／非 Apple 認證

iMac Solo 與 Apple、BetterDisplay、ScreenOff、MacDisplay 無關，也不受其背書。Apple [App Review Guidelines §2.5.1](https://developer.apple.com/app-store/review/guidelines/) 要求使用公開 API；本工具使用非公開介面，**不應宣稱符合 Mac App Store 上架規則**。另應留意 [Apple Developer Program Agreement](https://developer.apple.com/support/terms/apple-developer-program-license-agreement/) 對私有 API 的規定。

發布狀態：**experimental / pre-release**。並非已通過 iMac M1＋macOS 27 硬體驗證的穩定版。
