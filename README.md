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

所有名稱以 8 位數日期開頭的資料夾，都會套用相同的內部整理規則。

## 編輯過的 iPhone 相片

若存在：

```text
IMG_1234.HEIC
IMG_E1234.JPG
IMG_1234.AAE
```

整理後會變成：

```text
IMG_1234.JPG
Originals/
  IMG_1234.HEIC
  AAE/
    IMG_1234.AAE
```

編輯後版本是主檔；原始媒體不刪除。

## 非標準檔名

非 `IMG_####` 的媒體檔案會改成：

```text
YYYYMMDD-HHMMSS_原始檔名.ext
```

例如：

```text
20260921-184501_A8F21D3C-91AE-4F44.JPG
```

同 basename 的照片與影片會使用同一組拍攝時間。

## 日期來源

依序使用：

1. 若已安裝 ExifTool：媒體內的拍攝 / 建立時間。
2. macOS Spotlight metadata（`mdls`）。
3. 檔案 birth time。
4. 檔案 modification time。

ExifTool 不是必要套件。

## 安全規則

- 不覆寫既有檔案。
- 同一組照片只要遇到目的檔名衝突，整組跳過。
- 不跨磁碟搬移。
- 同組中途失敗會盡量回滾。
- `Originals` 子資料夾不會被再次處理。
- 腳本只自動處理根目錄，以及名稱以 8 位數日期開頭的第一層資料夾。
