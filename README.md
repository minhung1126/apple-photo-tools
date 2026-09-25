# apple-photo-tools

給 **macOS + iPhone 相片歸檔** 使用的半自動整理工具。

這個 repository 的核心檔案是：

```text
photo-organize.command
```

設計情境是：

1. 從 iPhone 把照片、影片直接匯出成一般檔案。
2. 你想把值得獨立收藏的活動先手動分成「主題資料夾」。
3. 其他沒有特別分類的散圖，交給工具自動按月份收進「日常資料夾」。
4. iPhone 編輯過的照片以 **編輯後版本當主檔**。
5. 原始檔不刪除，而是收進 `Originals/`。
6. 日常照片用 metadata 日期重新命名，方便長期依檔名排序與歸檔。
7. 主題照片已有日期與主題資料夾，因此一般媒體檔名全部保留；只有 `IMG_E#### → IMG_####` 的編輯版升級會改名。

---

## 最後想得到的結構

例如整理 2026 年 9 月的照片：

```text
Photo Archive/
├── photo-organize.command
│
├── 20260900/
│   ├── 20260903-102314_IMG_1234.HEIC
│   ├── 20260903-102314_IMG_1234.MOV
│   ├── 20260908-184522_IMG_1287.JPG
│   ├── 20260921-091433_A8F21D3C-91AE-4F44.JPG
│   └── Originals/
│       ├── IMG_1287.HEIC
│       └── AAE/
│           └── IMG_1287.AAE
│
├── 20260910 QWER/
│   ├── IMG_5321.JPG
│   ├── IMG_5322.HEIC
│   ├── IMG_5322.MOV
│   ├── A8F21D3C-AAAA-BBBB.JPG
│   └── Originals/
│       └── ...
│
└── 20260918 棒球/
    ├── IMG_6012.JPG
    ├── IMG_6013.JPG
    └── Originals/
```

其中：

- `YYYYMM00` = **日常資料夾**
- `YYYYMMDD 主題` = **主題資料夾**
- `Originals/` = 被編輯版取代後的原始媒體
- `Originals/AAE/` = Apple 編輯 sidecar

---

# 使用方式

## 1. 準備照片根目錄

把 `photo-organize.command` **複製到這次要整理的照片所在根目錄**。

例如：

```text
2026 Photos/
├── photo-organize.command
├── IMG_1001.HEIC
├── IMG_1002.HEIC
├── IMG_1002.MOV
├── IMG_1003.HEIC
├── IMG_E1003.JPG
├── IMG_1003.AAE
└── ...
```

程式執行時會自動把 **`.command` 所在資料夾** 當成工作根目錄。

不需要在 Terminal 裡手動輸入路徑。

---

## 2. 先手動建立你想保留的主題

如果某批照片你知道要獨立收藏，例如 QWER、棒球、旅行，可以在執行前先建立：

```text
20260910 QWER/
20260918 棒球/
20261003 東京/
```

然後把相片先手動放進去。

### 主題資料夾格式

建議：

```text
YYYYMMDD 主題
```

例如：

```text
20260910 QWER
20260918 棒球
```

程式辨認的第一層歸檔資料夾是：

```text
YYYYMMDD
```

或：

```text
YYYYMMDD 任意文字
```

也就是「8 位數日期」或「8 位數日期 + 空格 + 主題」。

### 工具不會自動猜主題

它不會分析照片內容，也不會判斷哪張照片是 QWER、棒球或旅行。

**你要分主題的照片必須先自己放進主題資料夾。**

留在根目錄的照片會被視為日常散圖。

---

## 3. 雙擊執行

雙擊：

```text
photo-organize.command
```

工具會分三個階段執行：

1. 根目錄散圖 → 按月份整理
2. iPhone 編輯版 / 原始檔 / AAE 整理
3. 依「日常 / 主題」規則重新命名

每一階段都會：

```text
顯示完整預覽
↓
等待確認
↓
只有輸入 YES
↓
才真的操作檔案
```

輸入其他內容都不會執行該階段。

---

# 核心規則

## 規則 1：根目錄的散圖自動按月份分類

例如根目錄有：

```text
IMG_1001.HEIC
IMG_1002.HEIC
IMG_1002.MOV
IMG_2001.JPG
```

程式會讀取拍攝時間，按月份放進：

```text
20260900/
20261000/
```

### 日常資料夾名稱

固定格式：

```text
YYYYMM00
```

例如：

```text
20260900
20261000
20261100
```

最後兩位使用 `00`，代表它不是某一天的主題，而是「該月份的日常散圖」。

---

# 日常 vs 主題：命名策略不同

這是本工具最重要的設計。

## A. 日常：`YYYYMM00`

日常照片沒有主題資料夾提供精確日期資訊，因此 **所有主媒體都使用拍攝 metadata 重新命名**。

格式：

```text
YYYYMMDD-HHMMSS_原始檔名.ext
```

例如：

```text
IMG_1234.HEIC
```

變成：

```text
20260925-142530_IMG_1234.HEIC
```

這樣 Finder 只要依名稱排序，就大致等於依拍攝時間排序。

而且仍然保留原本的 `IMG_1234`，方便追溯 Apple 原始編號。

### 日常中的標準 IMG 也會改名

即使原本已經是：

```text
IMG_1234.HEIC
```

在 `YYYYMM00` 裡仍會變：

```text
20260925-142530_IMG_1234.HEIC
```

這是刻意的設計。

---

## B. 主題：`YYYYMMDD 主題`

例如：

```text
20260910 QWER/
```

資料夾名稱本身已經提供：

- 日期：`20260910`
- 主題：`QWER`

因此標準 iPhone 檔名：

```text
IMG_5321.JPG
IMG_5322.HEIC
IMG_5322.MOV
```

**保持原名，不加日期前綴。**

目的是避免得到過度冗長的：

```text
20260910-193422_IMG_5321.JPG
```

### 主題中的非標準 / 亂碼檔名也保持原名

例如：

```text
A8F21D3C-91AE-4F44.JPG
odd name.jpg
60581595025__E39E8118.HEIC
```

都會保持原名。

主題資料夾的原則是：

> **一般媒體完全不做 metadata 重新命名。**

唯一例外是 Apple 編輯照片的整理：

```text
IMG_E1234.JPG
→ IMG_1234.JPG
```

這不是 metadata 命名，而是把編輯後版本升成主檔；對應原始檔仍會進 `Originals/`。

---

# iPhone 編輯過的照片

Apple 匯出後可能同時存在：

```text
IMG_1234.HEIC
IMG_E1234.JPG
IMG_1234.AAE
```

本工具的原則是：

> **編輯後版本是主要瀏覽 / 使用版本，原始版本保留到 Originals。**

---

## 主題資料夾中的編輯照片

原本：

```text
20260910 QWER/
├── IMG_1234.HEIC
├── IMG_E1234.JPG
└── IMG_1234.AAE
```

整理後：

```text
20260910 QWER/
├── IMG_1234.JPG
└── Originals/
    ├── IMG_1234.HEIC
    └── AAE/
        └── IMG_1234.AAE
```

也就是：

```text
IMG_1234.HEIC
→ Originals/IMG_1234.HEIC

IMG_E1234.JPG
→ IMG_1234.JPG

IMG_1234.AAE
→ Originals/AAE/IMG_1234.AAE
```

`E` 會從主檔檔名移除。

---

## 日常資料夾中的編輯照片

日常還會多一步 metadata 命名。

原本：

```text
IMG_1234.HEIC
IMG_E1234.JPG
IMG_1234.AAE
```

最後：

```text
20260900/
├── 20260925-142530_IMG_1234.JPG
└── Originals/
    ├── IMG_1234.HEIC
    └── AAE/
        └── IMG_1234.AAE
```

### 日常編輯照片的日期優先讀原始檔

如果存在：

```text
Originals/IMG_1234.HEIC
```

程式在替編輯後主檔重新命名時，會 **優先讀這個原始檔的拍攝 metadata**。

也就是：

```text
Originals/IMG_1234.HEIC
          ↓ 拍攝時間
20260925-142530_IMG_1234.JPG
```

這可以降低編輯 App 或匯出流程改變「編輯後檔案建立時間」造成錯誤日期的風險。

如果找不到原始檔，才會使用目前主檔自己的 metadata。

---

# AAE 的處理

`.AAE` 是 Apple 用來保存照片編輯資訊的 sidecar。

本工具：

- 不刪除 AAE
- 不把 AAE 當照片
- 不用 AAE 做檔名日期
- 收進：

```text
Originals/AAE/
```

例如：

```text
IMG_1234.AAE
→ Originals/AAE/IMG_1234.AAE
```

這樣主資料夾保持乾淨，但 Apple 編輯相關資料仍留存。

---

# Live Photo

一般未編輯 Live Photo 常見為：

```text
IMG_4321.HEIC
IMG_4321.MOV
```

它們 basename 相同，因此工具會把它們視為同一組。

## 日常 Live Photo

會共用同一個時間前綴：

```text
20260925-150102_IMG_4321.HEIC
20260925-150102_IMG_4321.MOV
```

不會出現：

```text
20260925-150102_IMG_4321.HEIC
20260925-150103_IMG_4321.MOV
```

只要它們原本 basename 相同，就會使用同一組拍攝時間。

## 主題 Live Photo

標準名稱保持：

```text
IMG_4321.HEIC
IMG_4321.MOV
```

不額外改名。

### 編輯過的 Live Photo

只要存在符合 `IMG_####.*` / `IMG_E####.*` 的媒體，會依「編輯版為主、原始媒體進 Originals」的規則處理。

工具不會自行生成缺少的 HEIC 或 MOV，也不會重新封裝 Live Photo。

---

# 非標準 / 亂碼檔名

iPhone 相簿裡不一定所有檔案都叫：

```text
IMG_1234.HEIC
```

從 App、訊息、AirDrop、下載或其他來源存進照片的檔案可能是：

```text
A8F21D3C-91AE-4F44.JPG
60581595025__E39E8118....HEIC
odd name.jpg
```

## 在日常 `YYYYMM00`

仍會保留完整原始 basename，只在前面加拍攝時間：

```text
YYYYMMDD-HHMMSS_原始檔名.ext
```

例如：

```text
A8F21D3C-91AE-4F44.JPG
→ 20260921-184501_A8F21D3C-91AE-4F44.JPG
```

## 在主題 `YYYYMMDD 主題`

完全保持原名：

```text
A8F21D3C-91AE-4F44.JPG
odd name.jpg
```

不會加日期，也不會清理或標準化檔名。

因此現在的命名界線非常明確：

> **日常靠檔名承載時間；主題靠資料夾承載日期與語意。**

---

# 防止重複重新命名

已經符合：

```text
YYYYMMDD-HHMMSS_...
```

格式的媒體會直接跳過。

所以重新執行工具不會變成：

```text
20260925-150000_20260925-150000_IMG_1234.HEIC
```

工具可以重複執行。

---

# 拍攝日期 / metadata 的來源順序

工具需要真正可用的媒體時間來：

- 判斷根目錄散圖該進哪個 `YYYYMM00`
- 替日常照片重新命名

## 1. ExifTool

如果系統有安裝 ExifTool，優先讀：

- `DateTimeOriginal`
- `CreateDate`
- `MediaCreateDate`
- `TrackCreateDate`

並使用第一個有效值。

如果有 Homebrew，可安裝：

```bash
brew install exiftool
```

## 2. macOS Spotlight content metadata

如果 ExifTool 沒有可用時間，會嘗試：

```text
kMDItemContentCreationDate
```

這仍屬於媒體內容層級的建立時間。

## 不再使用的時間

工具**不會**拿以下 filesystem 時間冒充拍攝時間：

- `kMDItemFSCreationDate`
- filesystem birth time
- modification time

因為這些值很可能只是：

- 下載時間
- 複製時間
- 匯出時間
- 雲端重新建立檔案的時間

而不是真正拍攝時間。

## 找不到拍攝時間時

如果整組照片 / Live Photo / 影片都找不到可用拍攝 metadata：

```text
[WARN] 找不到拍攝時間 metadata ...
```

然後：

- 根目錄散圖：**留在根目錄，不建立猜測月份**
- 已在 `YYYYMM00` 的日常檔案：**保持原檔名，不重新命名**
- 不會使用檔案建立時間或修改時間硬猜日期

如果同一組 Live Photo 或相關媒體中只有部分檔案有拍攝時間，會使用同組第一個可用的拍攝 metadata，讓整組維持一致時間前綴。

---

# 支援的檔案

## 圖片

```text
.jpg
.jpeg
.heic
.heif
.png
.dng
.tif
.tiff
.gif
.webp
```

## 影片

```text
.mov
.mp4
.m4v
```

副檔名判斷不分大小寫。

## Apple sidecar

```text
.aae
```

其他副檔名不會被當作相片 / 影片自動整理。

---

# 實際處理順序

程式固定分三階段。

這個順序很重要。

## Stage 1：散圖按月份整理

只掃描 **`.command` 所在根目錄的檔案**。

例如：

```text
IMG_1234.HEIC
IMG_1234.MOV
```

讀到 2026-09-25 後：

```text
20260900/
├── IMG_1234.HEIC
└── IMG_1234.MOV
```

這個階段先搬資料夾，還沒有進行日常最終檔名整理。

---

## Stage 2：編輯版與原始檔整理

掃描第一層的日期 / 主題資料夾。

處理：

- `IMG_E####`
- 對應的 `IMG_####`
- `.AAE`

編輯版升成主檔。

原始媒體進：

```text
Originals/
```

AAE 進：

```text
Originals/AAE/
```

---

## Stage 3：Metadata 檔名整理

最後才做檔名。

### 日常

```text
YYYYMM00/
```

全部主媒體：

```text
IMG_####
非標準檔名
```

都會依 metadata 加日期。

### 主題

```text
YYYYMMDD 主題/
```

Stage 3 **完全不做一般重新命名**。

以下都保持原名：

```text
IMG_1234.HEIC
IMG_1234.MOV
A8F21D3C-91AE-4F44.JPG
odd name.jpg
```

但 Stage 2 的編輯照片邏輯仍照常執行：

```text
IMG_E1234.JPG
→ IMG_1234.JPG

IMG_1234.HEIC
→ Originals/IMG_1234.HEIC
```

---

# 安全規則

這個工具的設計原則是：

> 寧可跳過，不要覆寫或猜錯。

## 1. 每個階段先 Preview

不會雙擊後立即大量搬檔。

每一階段都先顯示：

```text
來源
→ 目的地
```

只有輸入：

```text
YES
```

才執行。

---

## 2. 不覆寫既有檔案

實際搬移使用 macOS：

```text
mv -n
```

如果目的地已存在，不直接覆寫。

程式也會在操作前與操作後再次檢查檔案狀態。

---

## 3. 同一組遇到衝突，整組跳過

例如一組 Live Photo：

```text
IMG_1234.HEIC
IMG_1234.MOV
```

只要其中一個目的檔名發生衝突，整組不應只搬一半。

---

## 4. 同一組中途失敗會嘗試 rollback

如果同組有多個檔案，前幾個已搬成功、後面失敗，工具會盡量把已完成的動作搬回原位置。

rollback 本身若因檔案系統狀態改變而失敗，Terminal 會顯示 `ROLLBACK ERROR`。

---

## 5. 不跨磁碟搬移

每個 move 前會比對來源與目的地所在 filesystem device。

如果判斷為不同裝置，該組跳過。

本工具是「整理同一個照片歸檔根目錄」，不是跨硬碟搬運工具。

---

## 6. 不刪除原始照片

工具沒有「為了節省空間把原始照片刪掉」的流程。

編輯照片的原始媒體改為移到：

```text
Originals/
```

AAE 移到：

```text
Originals/AAE/
```

---

## 7. 沒有拍攝時間就不猜

如果找不到真正的拍攝 / 媒體建立 metadata：

- 顯示 `[WARN]`
- 不使用 filesystem 建立 / 修改時間代替
- 根目錄檔案保持原位
- 日常資料夾內檔案保持原檔名

## 8. Originals 不會再次自動整理

程式只掃描：

- 根目錄檔案
- 第一層符合日期格式的資料夾內檔案

不會進入：

```text
Originals/
Originals/AAE/
```

再次重新命名。

---

# 掃描範圍

工具不是遞迴式「掃完整顆硬碟」。

只處理：

## 根目錄

也就是：

```text
photo-organize.command
```

所在資料夾的直接檔案。

## 第一層日期資料夾

符合：

```text
YYYYMMDD
```

或：

```text
YYYYMMDD 任意文字
```

例如：

```text
20260900/
20260910/
20260910 QWER/
20260918 棒球/
```

更深層的其他自建資料夾不會被當成新的主題遞迴處理。

---

# 這個工具不做什麼

為了避免誤解，它 **不會**：

- 自動辨識照片內容或人物
- 自動判斷 QWER / 棒球 / 旅行等主題
- 自動把某一天的日常照片變成主題
- 刪除原始照片
- 覆寫已存在的目的檔案
- 修改 EXIF / metadata
- 轉換 HEIC / JPG / MOV 格式
- 壓縮照片或影片
- 自動去重複照片
- 合併或重建 Live Photo
- 匯入 / 匯出 Apple Photos Library
- 操作 iCloud Photos
- 遞迴整理整顆硬碟
- 重新整理 `Originals/` 裡面的原檔

它只負責：

> **安全地重新分類、升級編輯版、保存原始檔，以及只在日常資料夾依規則重新命名。**

---

# 建議工作流程

完整建議流程：

```text
iPhone
  ↓ USB-C
macOS Image Capture / 影像擷取
  ↓
暫存 / 歸檔根目錄
  ↓
先手動建立主題資料夾
  ↓
把主題照片放進去
  ↓
其餘散圖留在根目錄
  ↓
複製 photo-organize.command 進根目錄
  ↓
雙擊
  ↓
Stage 1 Preview → YES
  ↓
Stage 2 Preview → YES
  ↓
Stage 3 Preview → YES
  ↓
人工抽查照片 / 影片
  ↓
第二份備份
  ↓
再決定是否清空 iPhone
```

第一次在真實照片庫使用時，建議先用一小批「複製出來的測試照片」確認自己的 iPhone / Image Capture 匯出格式與預期一致。

---

# 第一次雙擊無法執行時

Git repository 中 `photo-organize.command` 已設定 executable bit。

但如果經過某些下載 / 解壓 / 檔案系統後執行權限遺失，可以在 Terminal 執行：

```bash
chmod +x photo-organize.command
```

之後再雙擊。

如果 macOS 因為下載來源的安全機制阻擋，請依 macOS 顯示的安全提示確認檔案來源後再允許執行。

---

# 自動測試

Repository 內含 macOS GitHub Actions。

測試在真正的 macOS runner 上執行：

```text
zsh -n photo-organize.command
```

並建立假的照片檔案驗證實際行為。

目前測試涵蓋：

- `.command` zsh 語法正確
- executable 權限存在
- 根目錄散圖進入當月 `YYYYMM00`
- 日常 `IMG_####` 會加 metadata 時間
- 主題 `IMG_####` 維持原名
- 主題中的標準與非標準一般媒體都保持原名
- `IMG_E####` 編輯版成為主檔
- 原始 `IMG_####` 進入 `Originals/`
- AAE 進入 `Originals/AAE/`
- 原檔與編輯版副檔名相同時不互相覆寫
- 日常編輯版完成後再進行 metadata 命名
- 日常 Live Photo HEIC + MOV 使用相同時間前綴
- 日常中含空格的非標準檔名可正常處理
- 主題中含空格 / UUID / 亂碼檔名不會被重新命名

---

# 設計摘要

如果只想記住幾條：

### 散圖

```text
留在根目錄
→ 自動依月份進 YYYYMM00
```

### 日常

```text
YYYYMM00
→ 全部主媒體使用 metadata 命名
```

### 主題

```text
YYYYMMDD 主題
→ 一般媒體全部保留原檔名
→ IMG_E#### 仍會升成 IMG_####
→ 對應原始檔仍進 Originals
```

### 編輯照片

```text
IMG_E#### = 主版本
IMG_####  = Originals
AAE       = Originals/AAE
```

### 安全

```text
Preview
→ YES
→ 不覆寫
→ 衝突整組跳過
→ 失敗盡量 rollback
```
