# 第三方授權與公開發布稽核（iMac Solo 0.1.0）

**審查日期：2026-11-05**  
**範圍：**上次交付的 iMacSolo 0.1.0 ZIP 所有 17 個項目（5 個 `Sources/*.swift`、2 個 `Tests/*`、3 個 `.command`、plist、授權、技術文件、HTML、說明、雜湊清單），及這次新增的 GitHub 文件、CI 設定與 `發布到GitHub.command`。  
**結論：有限度的檔案及授權盤點已完成；不構成法律上的完整權利保證。** 沒發現隨附第三方執行期套件；尚有一項主要未決事項（跨專案完整程式碼相似度／衍生作品鑑別）。可先作 **experimental source release**，但不應標示為「零侵權風險」或「macOS 27 實測通過」。

## 1. 方法與證據

- 解壓縮原始來源，逐檔閱讀主要 Swift／shell 程式、`Info.plist`、隨附 HTML、`docs/SOURCES.md`、現有 MIT 文件。
- 使用靜態關鍵字檢查 `import`、`dlopen`、`dlsym`、下載／安裝外部套件命令、第三方資源與版權註記；確認沒有 vendored `.framework`、套件 manifest、二進位庫、遠端字型／圖片或遠端 JS。
- 重新執行 `53` 項純政策測試、五份 Swift 原始碼語法解析、原包三個 shell script 與新增發布腳本的 `bash -n` 與 `Tests/audit.py` 靜態測試。
- 查閱 GitHub 公開專案頁及 Apple 官方開發文件；後續透過已連接的 GitHub 介面直接核對 ScreenOff 和 MacDisplay 的 LICENSE，並讀取 MacDisplay 的 `core.swift` 關鍵相關片段；但未完成其與本專案所有檔案的逐行／語義相似度比對。
- 本次為**技術性開源合規盤點**，不包含法律專業意見、人工律師審核、軟體專利檢索、第三方完整原始碼逐行 diff 或 Mac 實機測試。

## 2. 第三方來源／依賴表

| 名稱與性質 | 狀態 | 已確認授權 | 使用／處理方式 | 風險 |
|---|---|---|---|---|
| iMac Solo Swift、shell、文件 | 本包內部 | 檔案聲明 MIT；`LICENSE` | 以本儲存庫可授權內容為範圍發行 | 作者權利與 AI 內容可保護性應由維護者核對 |
| Apple AppKit / Foundation / CoreGraphics / Darwin | macOS 系統 SDK；**沒有複製進包** | Apple 平台 SDK 條款，不是 MIT | 系統框架 import／連結 | Apple 條款與相容性 |
| Apple SkyLight 非公開符號 | macOS 執行期動態查找 | 非公開 API，不提供穩定第三方授權承諾 | `dlopen`／`dlsym` 呼叫；不分發 Apple library | **高：**SDK／平台合規、系統更新失效 |
| zy0816/ScreenOff（DisplayToggle） | **技術參考**；無隨附原碼或 binaries | **MIT（LICENSE 原文核對，Copyright 2026 zy0816）** | 原作者與來源列於 `THIRD_PARTY_NOTICES.md` | 低～中，實質複製時必須附原授權告知 |
| jjongkwann/MacDisplay | **技術參考**；無隨附原碼或 binaries | **MIT（LICENSE 原文核對，Copyright 2026 jjongkwann）** | 保留出處；不重製其程式碼 | **中：**引用其技術模式，仍應查核完整程式碼相似性與適當歸屬 |
| oabdrabo/DisplayDeck | MacDisplay README 的間接來源 | MacDisplay LICENSE 明載源自 DisplayDeck 並署名其 MIT 授權；本次未獨立讀取 DisplayDeck 原始授權 | 無直接依賴或原碼納入 | 間接來源，僅記錄 |
| janten/disable-monitor | MacDisplay README 的間接來源 | MacDisplay README 說 GPL-2.0；未獨立核對 | 未納入、不可假定能以 MIT 重新授權 | 若日後複製則需重新審核相容性 |
| BetterDisplay | 第三方商用 App，僅比較背景 | 專有授權／未核實細則 | 無程式碼或商標圖像納入 | 低，避免品牌混淆 |
| actions/checkout@v4 | **CI-only** GitHub Action | **MIT（官方 README 確認）** | workflow 執行、未封裝進 App | 低，依 GitHub Actions 使用條款 |

## 3. 相關證據連結

- ScreenOff repository / MIT badge: https://github.com/zy0816/ScreenOff
- MacDisplay MIT LICENSE（已核對原文，blob SHA `882210411c96f125c7ff2fb0c4b0e0e7631f50a4`）: https://github.com/jjongkwann/MacDisplay/blob/main/LICENSE
- ScreenOff MIT LICENSE（已核對原文，blob SHA `9944cf69f62d7ba5e9852abc6ddcb5e43e0798be`）: https://github.com/zy0816/ScreenOff/blob/main/LICENSE
- `actions/checkout` MIT: https://github.com/actions/checkout
- Apple CoreGraphics: https://developer.apple.com/documentation/coregraphics/core-graphics-functions
- Apple App Review Guidelines, 2.5.1 public APIs: https://developer.apple.com/app-store/review/guidelines/
- Apple Developer Program License Agreement: https://developer.apple.com/support/terms/apple-developer-program-license-agreement/
- GitHub licensing repository guidance: https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/licensing-a-repository

## 4. 授權結論（與不能證明的事）

**有根據的結論**

- 原始交付檔案沒有第三方 SwiftPM 套件、CocoaPods、Homebrew runtime 依賴、商用 App binaries、下載型安裝指令或外部 Web 資源。只有系統框架及兩個執行期查找的 macOS 私有函式。
- `LICENSE.txt` 是標準 MIT 授權文字，GitHub 版另提供相同內容的 `LICENSE`。
- ScreenOff 的 LICENSE 原文確認為 MIT、Copyright (c) 2026 zy0816；僅**引用方法與標示技術來源**不等於使用其受保護原始碼；若未來實際納入，需要保留 MIT 版權與授權告知。
- MacDisplay 的 LICENSE 原文確認為 MIT、Copyright (c) 2026 jjongkwann；其授權還保留 DisplayDeck 的衍生來源聲明。**已解決 MacDisplay 授權全文未核實問題，但不能因此推定所有技術源頭均經完整清權。**

**未決事項／風險**

- **U1（部分解決）：**已取得並核對 MacDisplay 的 MIT LICENSE，且查看 `core.swift` 中的關鍵非公開 API 介面片段；**尚未完成** iMac Solo 與 ScreenOff、MacDisplay 以及間接來源的完整逐行 diff、clone detection 或語義／衍生作品分析。不能作出「絕無直接或實質複製」的法律保證。
- **U2：**沒有以 Apple Mac SDK 完成完整 build/type-check，也沒有 macOS 27／iMac M1 實測。這是品質與安全風險，而非第三方 MIT 授權衝突。
- **U3：**Apple Developer Program Agreement 可能禁止開發／散布使用私有 API 的某些應用；特別是 Mac App Store 的 2.5.1 限制。GitHub 釋出源碼**不代表**Apple 認可技術或合法分發任何平台上的安裝包。
- **U4：**AI 協助生成程式碼的權利歸屬與實際可保護性受到適用法律影響，MIT 應僅授權專案維護者有權授權的部分。維護者需要確認第三方貢獻的來源。

### 補充：MacDisplay 顯示器橋接的定點文字比對（2026-11-05）

對本專案 `Sources/DisplayBridge.swift` 去除空白並略去 `//` 註解後，抽出長度至少 45 個字元的 66 條不同程式碼行，以 FNV-1a 32-bit 指紋與 MacDisplay 現行 `core.swift`、`main.swift`、`menubar.swift` 的 88 條對應長行做**完全相同長行**比對：僅有 **2 條重合**（本專案 `DisplayBridge.swift` 第 110、132 行；MacDisplay `core.swift` 第 123、134 行）。其內容分別是從 `NSScreen.deviceDescription` 讀取顯示器編號、與 `CGBeginDisplayConfiguration` 的標準 API 呼叫句式，並非足以證明實質複製的獨創演算法或完整函式。

比對來源：MacDisplay [`core.swift`](https://github.com/jjongkwann/MacDisplay/blob/main/core.swift)（blob SHA `abda52309640d074b8fa10ca0d858807b3f6d02f`）及同一分支的 `main.swift`／`menubar.swift`。**限制：**這是逐行字面抽查，沒有檢測跨行、變數改名、抽象控制流程、ScreenOff Python 來源或全部間接來源；不能等同完整 clone detection 或法律清權。

## 5. 發布條件與後續建議

- 本次建議以 **public source / experimental / pre-release** 發行，而非宣稱「通過 Apple 認證的穩定 App」。
- 維護者應在 GitHub 個人帳號或組織下，核對 README、MIT Copyright 標示是否適用；如需以個人名義署名，先由帳號所有人自行確定姓名／公司及權利。
- 將來若有人 PR 提供其他工具程式碼，必須要求來源、SPDX 授權識別及原作者版權聲明，對未知／無授權／GPL 代碼重新審查，**不得直接以本專案 MIT 重新標示**。
- 如計畫發佈預編譯 `.app` 或 DMG，先完成實機測試、程式碼審查和 Apple 平台條款確認。
- 針對 U1，下一步需取得第三方全量原始碼，執行來源相似度檢查（保留比對記錄），並核對 DisplayDeck MIT 授權全文；必要時由維護者或法律專業人士判斷衍生作品的授權告知義務。

**審查狀態：檔案及依賴盤點已完成，ScreenOff、MacDisplay 的 MIT LICENSE 已直接核對；跨專案完整源碼比對及法律清權尚未完成。**

## 6. 2026-11-05 補充：GitHub 發布腳本與連線界線

新增 `發布到GitHub.command`（僅供使用者 Mac 本機執行）。此腳本使用 GitHub 官方 CLI `gh`，在本機完成檔案完整性確認、靜態規則與 macOS SDK 編譯後，需使用者輸入 `PUBLIC` 才會執行 `gh repo create ... --public --push`；不內嵌 Token、亦不會發佈二進位 App。腳本目前只做了語法與靜態審查，**沒有實際推送 GitHub**，也沒有在 Apple SDK 完整編譯。

ChatGPT 的 GitHub 連線已確認可讀取使用者儲存庫及外部授權檔，但目前沒有可建立新儲存庫的操作；GitHub CLI 為另外的 Mac 本機登入流程。這兩種登入狀態不能互相推定。
