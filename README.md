# KeyStroke

macOS 選單列按鍵浮層，支援快捷鍵歷史、媒體鍵、自訂外觀與位置記憶。
需要 macOS 13 以上，以及 Xcode 或可編譯 Swift 的 Apple 開發工具；回歸測試需要完整 Xcode。

## 操作

- 點選選單列鍵盤圖示 → **設定**。也可以再次開啟 App 來顯示設定視窗。
- 每個鍵帽代表一筆完整輸入，上方顯示該筆的修飾鍵，下方顯示主鍵。可保留 1–8 筆。
- **只顯示快捷鍵**：保留 Command／Control／Option 組合、F1–F20 及媒體鍵。一般文字、單獨 Shift 輸入、Return／Tab 等單獨按鍵不顯示。切換模式會清空舊紀錄。
- **暫停監聽**：停止事件監聽並清空浮層；繼續後只接收新的按鍵。**隱藏浮層**只切換視窗可見性。
- **解鎖位置**後可拖曳浮層；**重設位置**放回螢幕下方。
- 設定預覽與正式浮層共用相同鍵帽、間距及資料；較多筆時可水平捲動預覽。

首次啟動請依系統提示授予輔助使用權限。授權後會自動重試；若顯示「監聽啟動失敗」，檢查輔助使用與輸入監控權限後按 **重試**。重新編譯的 ad-hoc 簽章可能需要重新授權；App 不會自動修改系統權限。

先前的外觀、筆數、停留時間與位置設定會保留。「修飾鍵欄位數」已由每筆完整快捷鍵取代；仍可選擇隱藏修飾鍵。暫停為當次執行狀態，重新啟動 App 會重新嘗試監聽。

## 建置、執行與測試

```sh
./build.sh                         # 只建置，不安裝、不停止 App
./script/build_and_run.sh           # 建置成功後停止舊 App，再啟動新版
./script/build_and_run.sh --settings # 啟動並顯示設定
./script/test.sh                    # XCTest 回歸、Shell 語法及 plist 驗證
./package.sh                       # 建置 DMG，不安裝、不停止 App
./script/build_and_run.sh --install # 明確安裝到 /Applications
```

唯一建置入口是 `script/build_and_run.sh`；Codex Run 按鈕也使用它。`build.sh` 是相容入口。
App 產出於 `dist/KeyStroke.app`；DMG 名稱使用 `Resources/Info.plist` 的版本與實際架構，例如 `KeyStroke-1.0-arm64.dmg`。
預設編譯本機架構，可用 `KEYSTROKE_ARCH=arm64` 或 `KEYSTROKE_ARCH=x86_64` 指定。跨架構編譯不等於已在該硬體驗證。

建置在暫存 bundle 完成編譯與簽章驗證後才替換產物；失敗會保留上一版。安裝會把前一版留在輸出訊息指定的 `/Applications/.KeyStroke-install.*` 目錄，供手動回復。安裝不會自動重新啟動正在執行的 App。
目前使用本機 ad-hoc 簽章；公開發佈需要另行設定 Developer ID 簽章與 notarization。

## 診斷

```sh
./script/build_and_run.sh --telemetry
./script/build_and_run.sh --logs
./script/build_and_run.sh --verify
```

前兩者啟動 App 後以 unified logging 顯示 `com.keystroke.app` 日誌。日誌只記錄生命週期、監聽狀態與錯誤，不記錄輸入文字或按鍵內容，也不再建立桌面日誌。
`--verify` 只驗證指定 App 程序啟動，權限與實際鍵盤顯示需另做互動驗證。
