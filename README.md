# apple-photo-tools

macOS iPhone 相片歸檔工具。

## 使用方式

1. 把 `photo-organize.command` 複製到「要整理的照片根目錄」。
2. 先把需要自己定義主題的相片手動放進資料夾，例如：
   - `20260910 QWER`
   - `20260918 棒球`
3. 其他仍散在根目錄的照片不需要手動整理。
4. 雙擊 `photo-organize.command`。
5. 每個階段都會先顯示預覽；只有輸入大寫 `YES` 才會真的執行。

## 資料夾規則

根目錄散圖依拍攝月份進入「日常」資料夾：

```text
20260900
20261000
```

既有主題資料夾不移動、不改名：

```text
20260910 QWER
20260918 棒球
```

資料夾分成兩種：

- `YYYYMM00`：日常資料夾。裡面的主媒體全部依拍攝 metadata 命名。
- `YYYYMMDD 主題`：主題資料夾。標準 iPhone 檔名 `IMG_####` 保留原名，只有非標準檔名才依 metadata 命名。

## 編輯過的 iPhone 相片

若存在：

```text
IMG_1234.HEIC
IMG_E1234.JPG
IMG_1234.AAE
```

在主題資料夾中整理後會變成：

```text
IMG_1234.JPG
Originals/
  IMG_1234.HEIC
  AAE/
    IMG_1234.AAE
```

在日常 `YYYYMM00` 中，編輯後版本成為主檔後，會再依原始拍攝時間命名：

```text
20260925-142530_IMG_1234.JPG
Originals/
  IMG_1234.HEIC
  AAE/
    IMG_1234.AAE
```

日常編輯照片重新命名時，若 `Originals/IMG_1234.*` 存在，會優先從原始檔讀取拍攝時間；原始媒體本身不重新命名。

## 檔名規則

日常 `YYYYMM00`：

```text
IMG_1234.HEIC
IMG_1234.MOV
```

會變成：

```text
20260925-142530_IMG_1234.HEIC
20260925-142530_IMG_1234.MOV
```

主題 `YYYYMMDD 主題` 中的標準 `IMG_####` 保持不變；非標準檔名則改成：

```text
YYYYMMDD-HHMMSS_原始檔名.ext
```

例如：

```text
20260921-184501_A8F21D3C-91AE-4F44.JPG
```

同 basename 的照片與影片會使用同一組拍攝時間。已經是 `YYYYMMDD-HHMMSS_...` 的檔案不會再次重新命名。

## 日期來源

依序使用：

1. 若已安裝 ExifTool：媒體內的拍攝 / 建立時間。
2. macOS Spotlight metadata（`mdls`）。
3. 檔案 birth time。
4. 檔案 modification time。

ExifTool 不是必要套件。

## 安全規則

- 實際搬移使用 macOS `mv -n`，不覆寫既有檔案，且搬移後會再次驗證來源/目的地。
- 同一組照片只要遇到目的檔名衝突，整組跳過。
- 不跨磁碟搬移。
- 同組中途失敗會盡量回滾。
- `Originals` 子資料夾不會被再次處理。
- 腳本只自動處理根目錄，以及名稱以 8 位數日期開頭的第一層資料夾。


## 自動測試

Repository 內含 macOS GitHub Actions 測試，會檢查：

- `zsh -n` 語法。
- `.command` 保持 executable。
- 主題資料夾中的 `IMG_####` 維持原名。
- 日常 `YYYYMM00` 中的 `IMG_####` 會加上拍攝時間。
- `IMG_E####` 編輯版成為主檔。
- 同副檔名時先把原檔移至 `Originals/`，再把編輯版換成 `IMG_####`，避免覆寫。
- AAE 移至 `Originals/AAE/`。
- 根目錄散圖進入當月 `YYYYMM00`。
- 日常 Live Photo 的照片與 MOV 使用相同時間前綴。
- 日常編輯照片主檔使用原始檔 metadata（若原始檔存在）。
- 主題中的非標準檔名仍會依 metadata 重新命名。
