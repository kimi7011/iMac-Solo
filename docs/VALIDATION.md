# 驗證報告 — 2026-11-05

## 已執行

環境：Linux x86_64，Swift 6.2.1；不是 macOS，也沒有 Apple macOS SDK。

1. `swiftc -swift-version 5 Sources/Policy.swift Tests/main.swift ...`
   結果：成功編譯純政策測試；執行結果為 53 項 PASS。
   涵蓋：沒有外接螢幕、鏡像、休眠、虛擬／空槽位、失效或過大 ID、倒數邊界、
   未驗證不得保留、心跳逾時、父程序退出、手動還原、睡眠暫停、喚醒還原與關機不競爭。
   **沒有呼叫任何顯示器 API。**

2. `swiftc -frontend -parse Sources/*.swift`
   結果：五個 Swift 檔案通過語法解析。
   **這不是 Apple SDK 型別檢查，也不是 Mac App 編譯成功的證明。**

3. 三個 `.command` 的 `bash -n` 檢查。
   結果：語法通過。

4. `python Tests/audit.py`
   結果：單一受保護停用入口、session-only 提交、恢復紀錄先行、嚴格 boolean_t 比較、
   無下載第三方依賴命令、bundle metadata、腳本可執行位元等靜態檢查通過。

## 尚未執行／不能宣稱

- macOS SDK 完整型別檢查、連結與 codesign 實測。
- iMac M1 + macOS 27 的停用、恢復、背光與功耗量測。
- 使用者 USB-C／HDMI 轉接器及外接螢幕相容性。
- 視窗實際版面、Gatekeeper、睡眠、喚醒、登出、關機、拔線與程序故障的實機整合測試。

## 使用者 Mac 上的下一個驗證關卡

安裝器會先執行純政策測試，再利用該 Mac 的 Apple SDK 建置完整程式。
編譯或簽章失敗會停止並留下 `安裝記錄.log`，不會呼叫停用顯示器功能。
安裝成功後，仍需由使用者主動啟動 20 秒測試，在 HDMI 螢幕目視確認。

自動恢復屬最佳努力，不提供不會黑屏／不會當機的保證。

## GitHub 公開版補充

另加入 `發布到GitHub.command`，用來在使用者 Mac 上經 **明確 PUBLIC 確認** 後建立公開原始碼儲存庫。此檔案已通過 `bash -n` 與靜態審查；**尚未實際執行 GitHub 寫入、GitHub CLI 登入或 Apple SDK 編譯**。本機 Linux 的靜態測試不能替代這些驗證。
