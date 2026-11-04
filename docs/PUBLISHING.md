# GitHub 發布指南（實驗性原始碼）

## 推薦設定

- 儲存庫名稱：`iMac-Solo`（名稱可改）。
- 可見性：`Public`。
- 描述：`Experimental macOS menu bar tool to software-disconnect an iMac built-in display when a wired external monitor is active. No binary release; hardware unverified.`
- 主題：`macos`, `swift`, `imac`, `external-monitor`, `display-management`, `experimental`。
- 預設分支：`main`。
- 授權：已提供 `LICENSE`，不要在 GitHub 建立過程中重複自動產生不同授權。
- **不要把 repo 發布成 macOS 27 實機驗證版，也不要直接發布未測試的 .app／.dmg。**

## 0. 使用「發布到GitHub.command」（較省事）

1. 在 iMac 上先安裝 [GitHub CLI](https://cli.github.com/)，於 Terminal 執行 `gh auth login`（選擇透過瀏覽器登入）。這與 ChatGPT GitHub 外掛是不同的登入憑證。
2. 確認 `git config user.name` 與 `git config user.email` 已設定；可以用 GitHub 的 noreply Email 避免公開信箱。
3. 先人工核對 `LICENSE`、`THIRD_PARTY_NOTICES.md`、`docs/LICENSE_AUDIT.md` 與 `README.md`，確認是你願意公開的內容。
4. 雙擊 `發布到GitHub.command`。腳本會檢查檔案雜湊、測試政策規則、嘗試以 Mac SDK 編譯完整程式。**只有輸入 `PUBLIC` 才會建立公開 repo 並推送原始碼**。
5. 如果已有同名儲存庫或 `origin` 遠端，腳本會停止以免覆寫。上傳成功後到 GitHub 的 `Actions` 查看 CI。

這是便利的本機操作流程，不表示本專案已實測關閉 iMac M1 螢幕，也不表示授權法律清權已完全完成。若修改任何檔案，須更新 `SHA256SUMS.txt` 的檔案雜湊，否則校驗將失敗。

## 1. 使用 GitHub 網站建立空儲存庫

開啟 https://github.com/new → 輸入名稱 `iMac-Solo` → 選 `Public` → **不要勾選自動建立 README、.gitignore 或 LICENSE** → Create repository。

## 2. 在 Mac 終端機上傳

在解壓縮後、包含 `README.md` 與 `Sources/` 的專案根目錄執行：

```bash
git init
git branch -M main
git add .
git status
git commit -m "Initial experimental source release with license audit"
git remote add origin https://github.com/YOUR_GITHUB_USERNAME/iMac-Solo.git
git push -u origin main
```

把 `YOUR_GITHUB_USERNAME` 換成你的 GitHub 帳號名稱。首次執行可能需透過 GitHub Credential Manager、`gh auth login` 或其他受支援登入方式驗證；**不要把私人存取 Token 直接貼到聊天或存進原始碼**。

## 3. 發布前核對

- [ ] `LICENSE` 內容與自己有權授權的內容一致，署名已自行確認。
- [ ] `THIRD_PARTY_NOTICES.md`／`docs/LICENSE_AUDIT.md` 的限制與實際來源一致。
- [ ] `git status` 與 `.gitignore` 顯示未將 `安裝記錄.log`、API token、私有檔案、`.app` 編譯產物等放入版控。
- [ ] `SHA256SUMS.txt` 有效；安裝器檢查通過。
- [ ] CI 編譯狀態符合實際情況：如紅燈，修正再宣稱可建置；不應宣稱已有 macOS SDK 驗證。
- [ ] README 明確寫出未經硬體測試與 Apple 私有 API 風險。
- [ ] 不發布未經測試的正式穩定版二進位 Release；需要下載請使用 GitHub 原始碼 Zip。
- [ ] 公開前自行審閱智慧財產權及 Apple 平台相關條款；必要時請專業法律人士協助。

## 4. 版本與 Issues

初期可在 About／README 標記 `Experimental`; 先收集 Mac 型號、OS build、輸出方式的自願測試回報，**勿要求使用者分享序號、精確帳號資料、完整機器日誌或私人 Token**。需要測試時先提供 read-only 診斷及可還原路徑。
