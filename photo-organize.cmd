@echo off
setlocal EnableExtensions DisableDelayedExpansion
chcp 65001 >nul
set "SELF_PATH=%~f0"
set "PHOTO_ROOT=%~dp0"
if not "%~1"=="" set "PHOTO_ROOT=%~1"

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$p=$env:SELF_PATH; $s=[IO.File]::ReadAllText($p); $m='#'+' POWERSHELL-BEGIN'; $i=$s.IndexOf($m); if($i -lt 0){throw 'PowerShell marker not found.'}; Invoke-Expression ($s.Substring($i+$m.Length))"
set "RC=%ERRORLEVEL%"
endlocal & exit /b %RC%

# POWERSHELL-BEGIN

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)

function Write-Title([string]$Text) {
    Write-Host ''
    Write-Host ('=' * 72)
    Write-Host $Text
    Write-Host ('=' * 72)
}

function Wait-Menu {
    Write-Host ''
    [void](Read-Host '按 Enter 回到主選單')
}

function Confirm-Yes([string]$Message) {
    Write-Host ''
    Write-Host $Message -ForegroundColor Yellow
    $answer = Read-Host '輸入 YES 才會繼續'
    return ($answer -ceq 'YES')
}

function Assert-SameVolume([string]$Source, [string]$Destination) {
    $srcRoot = [IO.Path]::GetPathRoot([IO.Path]::GetFullPath($Source))
    $dstRoot = [IO.Path]::GetPathRoot([IO.Path]::GetFullPath($Destination))
    if (-not [string]::Equals($srcRoot, $dstRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw "偵測到跨磁碟操作：$srcRoot -> $dstRoot。已停止。"
    }
}

function Test-IsInsideRoot([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path)
    $rootWithSep = $script:Root.TrimEnd('\') + '\'
    return $full.StartsWith($rootWithSep, [StringComparison]::OrdinalIgnoreCase)
}

function Test-IsProtectedBaseName([string]$BaseName) {
    # iPhone 標準檔名、Apple 編輯版，以及本工具已格式化過的檔名都不再處理。
    if ($BaseName -match '^IMG_\d{4}$') { return $true }
    if ($BaseName -match '^IMG_E\d{4}$') { return $true }
    if ($BaseName -match '^\d{8}-\d{6}_.+$') { return $true }
    return $false
}

function Get-CaptureInfo([IO.FileInfo]$File) {
    # 優先使用 Windows Property System 讀取照片/影片內的拍攝資訊。
    try {
        $folder = $script:Shell.Namespace($File.DirectoryName)
        if ($null -ne $folder) {
            $item = $folder.ParseName($File.Name)
            if ($null -ne $item) {
                foreach ($propertyName in @(
                    'System.Photo.DateTaken',
                    'System.Media.DateEncoded',
                    'System.ItemDate'
                )) {
                    try {
                        $value = $item.ExtendedProperty($propertyName)
                        if ($null -eq $value) { continue }

                        $dt = $null
                        if ($value -is [DateTime]) {
                            $dt = [DateTime]$value
                        }
                        elseif (-not [string]::IsNullOrWhiteSpace([string]$value)) {
                            $parsed = [DateTime]::MinValue
                            if ([DateTime]::TryParse(
                                [string]$value,
                                [Globalization.CultureInfo]::CurrentCulture,
                                [Globalization.DateTimeStyles]::AllowWhiteSpaces,
                                [ref]$parsed
                            )) {
                                $dt = $parsed
                            }
                        }

                        if ($null -ne $dt -and $dt.Year -ge 1970 -and $dt.Year -le 2100) {
                            return [pscustomobject]@{
                                Time   = $dt
                                Source = $propertyName
                            }
                        }
                    }
                    catch {
                        # 該欄位讀不到時繼續嘗試下一個。
                    }
                }
            }
        }
    }
    catch {
        # Windows metadata 讀取失敗時使用檔案時間作為 fallback。
    }

    if ($File.CreationTime.Year -ge 1970 -and $File.CreationTime.Year -le 2100) {
        return [pscustomobject]@{
            Time   = $File.CreationTime
            Source = 'File.CreationTime'
        }
    }

    return [pscustomobject]@{
        Time   = $File.LastWriteTime
        Source = 'File.LastWriteTime'
    }
}

function Invoke-MoveAae {
    Write-Title '1) 移動 AEE'

    $files = @(
        Get-ChildItem -LiteralPath $script:Root -File -Force |
            Where-Object { $_.Extension -ieq '.AAE' } |
            Sort-Object Name
    )

    if ($files.Count -eq 0) {
        Write-Host '目前資料夾沒有 .AAE 檔案。'
        Wait-Menu
        return
    }

    $destDir = [IO.Path]::Combine($script:Root, 'aee')
    Assert-SameVolume $script:Root $destDir

    if (-not (Test-IsInsideRoot $destDir)) {
        throw "目的地不在目前資料夾內：$destDir"
    }

    $plan = @()
    foreach ($file in $files) {
        $destination = [IO.Path]::Combine($destDir, $file.Name)
        $blocked = [IO.File]::Exists($destination)

        $plan += [pscustomobject]@{
            Source      = $file.FullName
            Destination = $destination
            Blocked     = $blocked
        }
    }

    Write-Host ''
    Write-Host '預覽：'
    foreach ($item in $plan) {
        if ($item.Blocked) {
            Write-Host ("[SKIP: 同名已存在] {0} -> {1}" -f $item.Source, $item.Destination) -ForegroundColor DarkYellow
        }
        else {
            Write-Host ("[MOVE] {0} -> {1}" -f $item.Source, $item.Destination)
        }
    }

    $actionable = @($plan | Where-Object { -not $_.Blocked })
    if ($actionable.Count -eq 0) {
        Write-Host ''
        Write-Host '沒有可執行的項目。'
        Wait-Menu
        return
    }

    if (-not (Confirm-Yes "將移動 $($actionable.Count) 個 .AAE 檔案到 aee 子資料夾；不刪除、不覆寫。")) {
        Write-Host '已取消。'
        Wait-Menu
        return
    }

    [void][IO.Directory]::CreateDirectory($destDir)

    $moved = 0
    $failed = 0

    foreach ($item in $actionable) {
        try {
            if ([IO.File]::Exists($item.Destination)) {
                Write-Host ("[SKIP: 執行前發現同名] {0}" -f $item.Destination) -ForegroundColor DarkYellow
                continue
            }

            Assert-SameVolume $item.Source $item.Destination
            [IO.File]::Move($item.Source, $item.Destination)
            Write-Host ("[OK] {0}" -f [IO.Path]::GetFileName($item.Source)) -ForegroundColor Green
            $moved++
        }
        catch {
            Write-Host ("[ERROR] {0}: {1}" -f $item.Source, $_.Exception.Message) -ForegroundColor Red
            $failed++
        }
    }

    Write-Host ''
    Write-Host "完成：移動 $moved，失敗 $failed。"
    Wait-Menu
}

function Invoke-FormatNames {
    Write-Title '2) 格式化檔名'

    $mediaExtensions = @(
        '.jpg', '.jpeg', '.heic', '.heif', '.png', '.dng',
        '.tif', '.tiff', '.gif', '.webp',
        '.mov', '.mp4', '.m4v'
    )

    $imageExtensions = @(
        '.jpg', '.jpeg', '.heic', '.heif', '.png', '.dng',
        '.tif', '.tiff', '.gif', '.webp'
    )

    $candidates = @(
        Get-ChildItem -LiteralPath $script:Root -File -Force |
            Where-Object {
                ($mediaExtensions -contains $_.Extension) -and
                (-not (Test-IsProtectedBaseName $_.BaseName))
            } |
            Sort-Object Name
    )

    if ($candidates.Count -eq 0) {
        Write-Host '沒有需要格式化的檔案。'
        Write-Host '會自動跳過：IMG_0000、IMG_E0000、以及 YYYYMMDD-HHMMSS_... 格式。'
        Wait-Menu
        return
    }

    # 同一個 basename 的相片與 Live Photo MOV 視為同一組，
    # 共用同一個時間戳，避免重新命名後失去配對。
    $groups = @($candidates | Group-Object BaseName)
    $plan = @()

    foreach ($group in $groups) {
        $groupFiles = @($group.Group | Sort-Object Name)

        $primary = $groupFiles |
            Where-Object { $imageExtensions -contains $_.Extension } |
            Select-Object -First 1

        if ($null -eq $primary) {
            $primary = $groupFiles | Select-Object -First 1
        }

        $capture = Get-CaptureInfo $primary
        $prefix = $capture.Time.ToString('yyyyMMdd-HHmmss')

        $items = @()
        $blocked = $false

        foreach ($file in $groupFiles) {
            $newName = '{0}_{1}{2}' -f $prefix, $file.BaseName, $file.Extension
            $destination = [IO.Path]::Combine($script:Root, $newName)

            if (-not (Test-IsInsideRoot $destination)) {
                throw "產生的目的地不在目前資料夾內：$destination"
            }

            Assert-SameVolume $file.FullName $destination

            $itemBlocked = [IO.File]::Exists($destination)
            if ($itemBlocked) {
                $blocked = $true
            }

            $items += [pscustomobject]@{
                Source      = $file.FullName
                Destination = $destination
                Blocked     = $itemBlocked
            }
        }

        $plan += [pscustomobject]@{
            BaseName      = $group.Name
            CaptureTime   = $capture.Time
            CaptureSource = $capture.Source
            Items         = $items
            Blocked       = $blocked
        }
    }

    Write-Host ''
    Write-Host '預覽：'
    foreach ($groupPlan in $plan) {
        $timeText = $groupPlan.CaptureTime.ToString('yyyy-MM-dd HH:mm:ss')
        if ($groupPlan.Blocked) {
            Write-Host ("[SKIP GROUP: 目的檔名衝突] {0} | {1} | {2}" -f $groupPlan.BaseName, $timeText, $groupPlan.CaptureSource) -ForegroundColor DarkYellow
        }
        else {
            Write-Host ("[GROUP] {0} | {1} | {2}" -f $groupPlan.BaseName, $timeText, $groupPlan.CaptureSource)
        }

        foreach ($item in $groupPlan.Items) {
            if ($item.Blocked) {
                Write-Host ("    [CONFLICT] {0} -> {1}" -f [IO.Path]::GetFileName($item.Source), [IO.Path]::GetFileName($item.Destination)) -ForegroundColor DarkYellow
            }
            else {
                Write-Host ("    {0} -> {1}" -f [IO.Path]::GetFileName($item.Source), [IO.Path]::GetFileName($item.Destination))
            }
        }
    }

    $actionableGroups = @($plan | Where-Object { -not $_.Blocked })
    if ($actionableGroups.Count -eq 0) {
        Write-Host ''
        Write-Host '所有項目都有衝突，因此沒有可執行的重新命名。'
        Wait-Menu
        return
    }

    $fileCount = 0
    foreach ($groupPlan in $actionableGroups) {
        $fileCount += $groupPlan.Items.Count
    }

    if (-not (Confirm-Yes "將重新命名 $fileCount 個檔案，共 $($actionableGroups.Count) 組；不覆寫任何既有檔案。")) {
        Write-Host '已取消。'
        Wait-Menu
        return
    }

    $renamed = 0
    $failedGroups = 0

    foreach ($groupPlan in $actionableGroups) {
        $completed = New-Object System.Collections.Generic.List[object]

        try {
            # 執行前再次檢查整組，避免 preview 後目的檔突然出現。
            foreach ($item in $groupPlan.Items) {
                if ([IO.File]::Exists($item.Destination)) {
                    throw "目的檔案已存在：$($item.Destination)"
                }
            }

            foreach ($item in $groupPlan.Items) {
                Assert-SameVolume $item.Source $item.Destination
                [IO.File]::Move($item.Source, $item.Destination)
                [void]$completed.Add($item)
                $renamed++
            }

            Write-Host ("[OK GROUP] {0}" -f $groupPlan.BaseName) -ForegroundColor Green
        }
        catch {
            # 同組包含 Live Photo 時若中途失敗，盡量回滾已完成的 rename，
            # 避免 HEIC/JPG 與 MOV 被拆散。
            for ($i = $completed.Count - 1; $i -ge 0; $i--) {
                $done = $completed[$i]
                try {
                    if ([IO.File]::Exists($done.Destination) -and -not [IO.File]::Exists($done.Source)) {
                        [IO.File]::Move($done.Destination, $done.Source)
                        $renamed--
                    }
                }
                catch {
                    Write-Host ("[ROLLBACK ERROR] {0}: {1}" -f $done.Destination, $_.Exception.Message) -ForegroundColor Red
                }
            }

            Write-Host ("[ERROR GROUP] {0}: {1}" -f $groupPlan.BaseName, $_.Exception.Message) -ForegroundColor Red
            $failedGroups++
        }
    }

    Write-Host ''
    Write-Host "完成：重新命名 $renamed 個檔案；失敗群組 $failedGroups。"
    Write-Host 'IMG_0000 / IMG_E0000 會保留原名，因此原始版與 Apple 編輯版都不會被本工具合併或刪除。'
    Wait-Menu
}

try {
    $script:Root = [IO.Path]::GetFullPath($env:PHOTO_ROOT)

    if (-not [IO.Directory]::Exists($script:Root)) {
        throw "找不到資料夾：$script:Root"
    }

    $script:Shell = New-Object -ComObject Shell.Application

    while ($true) {
        Write-Title 'Apple Photo Tools'
        Write-Host "目前資料夾：$script:Root"
        Write-Host ''
        Write-Host '1) 移動 AEE'
        Write-Host '2) 格式化檔名'
        Write-Host 'q) 離開'
        Write-Host ''
        Write-Host '說明：'
        Write-Host '  - 1 只把目前資料夾的 .AAE 移到 .\aee\，不刪除。'
        Write-Host '  - 2 只處理非 IMG_0000 / IMG_E0000 的照片與影片。'
        Write-Host '  - 2 的格式：YYYYMMDD-HHMMSS_原始檔名.ext'
        Write-Host '  - 同 basename 的 Live Photo 相片 + MOV 使用同一時間戳。'
        Write-Host '  - 每次都會先預覽，再要求輸入 YES。'
        Write-Host '  - 不覆寫、不跨磁碟。'
        Write-Host ''

        $choice = (Read-Host '請選擇').Trim()

        switch ($choice.ToLowerInvariant()) {
            '1' { Invoke-MoveAae }
            '2' { Invoke-FormatNames }
            'q' { break }
            default {
                Write-Host '無效選項。'
                Start-Sleep -Milliseconds 700
            }
        }

        if ($choice.ToLowerInvariant() -eq 'q') {
            break
        }
    }
}
catch {
    Write-Host ''
    Write-Host ("致命錯誤：{0}" -f $_.Exception.Message) -ForegroundColor Red
    exit 1
}
