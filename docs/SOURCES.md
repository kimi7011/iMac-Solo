# 技術參考與驗證邊界

查閱日期：2026-11-05。以下來源用於確認介面原型、行為與安裝工具；
不代表來源作者驗證或背書 iMac Solo，也不代表 iMac M1 + macOS 27 已通過測試。

1. Apple — Installing the command-line tools
   https://developer.apple.com/documentation/xcode/installing-the-command-line-tools/
   說明 Apple Command Line Tools、Swift/SDK 工具鏈與 xcode-select --install。

2. Apple — Core Graphics Functions
   https://developer.apple.com/documentation/coregraphics/core-graphics-functions
   公開的線上顯示器列舉、內建辨識、顯示器重新設定通知及設定交易。

3. Apple — CGConfigureOption.forSession
   https://developer.apple.com/documentation/coregraphics/cgconfigureoption/forsession
   本程式選擇工作階段設定，不使用永久提交。

4. zy0816 / ScreenOff（DisplayToggle）— README 與 displaytoggle.py
   https://github.com/zy0816/ScreenOff
   https://raw.githubusercontent.com/zy0816/ScreenOff/main/displaytoggle.py
   參考非公開介面原型、已停用螢幕的列舉問題、虛擬替代螢幕、boolean_t 無效值及復原限制。
   README 記載另一種硬體 macOS 27.0 / M4 Pro 的行為；不可據此推定 iMac M1。

5. jjongkwann / MacDisplay — core.swift
   https://github.com/jjongkwann/MacDisplay/blob/main/core.swift
   參考執行時載入符號、顯示器 ID 重新列舉與 API 原型。

6. Apple — macOS 27
   https://www.apple.com/tw/os/macos/
   使用者自述的 macOS 27 版本名稱可在 Apple 官方頁面查核。

## 原創範圍

本包的 Swift UI、雙程序協定、守護狀態機、安全政策、測試與安裝腳本為本次獨立撰寫。
非公開 API 的名稱與呼叫約定是技術事實，不是 Apple 保證穩定的契約。
沒有拷貝第三方 App 二進位、沒有包含付費產品，也沒有要求停用 SIP。

## 未驗證項目

- 未在 macOS SDK 執行完整編譯／型別檢查；本次只有 Swift 語法解析。
- 未在 iMac M1、macOS 27、使用者轉接器與 HDMI 螢幕上測試。
- 未量測背光、電源、功耗與長期穩定性。
- 尚未測試實際睡眠、喚醒、關機、拔線、WindowServer 卡住和 Gatekeeper 的所有行為。
- 策略測試不會呼叫 CoreGraphics，不能證明私有 API 有效。

上述限制也在安裝說明與 App 首頁顯示。請勿將本包宣傳為已認證／保證相容。

## GitHub 公開版授權審查註記

正式的來源／授權盤點見 [`LICENSE_AUDIT.md`](LICENSE_AUDIT.md) 與根目錄
[`THIRD_PARTY_NOTICES.md`](../THIRD_PARTY_NOTICES.md)。已核對 MacDisplay 與 ScreenOff 的 MIT LICENSE 原文，但尚未完成跨專案所有來源的逐行／語義相似度比對，不能將這份參考資料清單當成「完全排除相似程式碼」的證明。
公開版披露 AI 協作撰寫，**不是** Apple 認證／Mac App Store 適用工具。
