# Third-party notices / 第三方來源聲明

這是 **attribution and dependency inventory（來源與依賴盤點）**，並不是宣稱下列開源專案的全部程式碼都包含在本儲存庫。

## 隨附／執行期依賴

- **第三方原始碼、二進位程式庫、圖像、字型、嵌入式 Web SDK：未發現。** Swift 原始碼引用 Apple 系統 `AppKit`、`Foundation`、`CoreGraphics`、`Darwin`，並在執行時查找 macOS 非公開 `SkyLight/CoreGraphics` 符號；沒有將 Apple 框架檔案放入儲存庫。
- **Swift／Apple Command Line Tools** 僅用於使用者本機建置，並非隨附之第三方依賴。
- GitHub Actions 的 `actions/checkout@v4` 是**僅限 CI 的開發工具**，MIT 授權。來源：https://github.com/actions/checkout 。未封裝進 iMac Solo App。

## 技術參考（未隨附其程式碼或二進位）

1. **zy0816 / ScreenOff (DisplayToggle)** — https://github.com/zy0816/ScreenOff
   - 直接核對 [`LICENSE`](https://github.com/zy0816/ScreenOff/blob/main/LICENSE)：**MIT License，Copyright (c) 2026 zy0816**；公開 README 的技術說明包括 macOS 非公開顯示器列舉及軟體中斷機制。
   - 本儲存庫不包含其原始碼或 binary；上述技術參考予以致謝。如果日後實際複製其有著作權的程式碼，須保留其原始版權及授權聲明。
2. **jjongkwann / MacDisplay** — https://github.com/jjongkwann/MacDisplay
   - 參考公開 README 討論的動態符號、顯示器 ID 重新列舉與恢復限制。
   - 已取得並直接核對 [`LICENSE`](https://github.com/jjongkwann/MacDisplay/blob/main/LICENSE)：**MIT License，Copyright (c) 2026 jjongkwann**（Git blob SHA `882210411c96f125c7ff2fb0c4b0e0e7631f50a4`）。本包並未封裝其原始碼。
   - 該 LICENSE 明載顯示器設定交易模式源於 `oabdrabo/DisplayDeck`（2025 DisplayDeck Contributors，MIT）；其 README 另提及 `janten/disable-monitor`（GPL-2.0）但聲明未複製 GPL 程式碼。這是 MacDisplay 自身的來源鏈說明，**不代表** iMac Solo 直接納入那些程式碼。
3. **Apple Developer documentation** — https://developer.apple.com/documentation/coregraphics/
   - 使用公開 API 文件確認型別及顯示器交易概念；本包不含 Apple 文件的複製文本、官方 SDK 原始碼或系統框架檔案。
4. **BetterDisplay** — https://betterdisplay.pro/
   - 僅在討論問題背景與比較時提及；本儲存庫沒有引用或重新散布其私有程式碼或圖像。品牌及商標屬其權利人。

這些來源及授權判斷於 **2026-11-05** 查閱。參考相關技術機制不等於授權可複製的特定程式碼表達；不能憑沒有依賴套件就斷言不存在著作權問題。跨專案完整的逐行／語義相似度比對並未完成，詳見 `docs/LICENSE_AUDIT.md`。
