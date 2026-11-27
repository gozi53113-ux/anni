# =====================================================================
#             NeKo VPN - Cong cu Build & Tu dong luu vao Thu muc Downloads
# =====================================================================
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$Host.UI.RawUI.WindowTitle = "NeKo VPN Builder"

$RepoUrl = "https://github.com/gozi53113-ux/anni"
$RepoApi = "https://api.github.com/repos/gozi53113-ux/anni"
$DownloadsDir = [System.IO.Path]::Combine($env:USERPROFILE, "Downloads")
$AdbPath = "D:\AndroidROM\AndroidSDK\platform-tools\adb.exe"

function Show-Header {
    Clear-Host
    Write-Host "======================================================" -ForegroundColor Cyan
    Write-Host "             🐾 NeKo VPN Builder (PowerShell)          " -ForegroundColor Yellow
    Write-Host "======================================================" -ForegroundColor Cyan
    Write-Host " Kho luu tru     : $RepoUrl" -ForegroundColor Gray
    Write-Host " Thu muc Tai ve  : $DownloadsDir" -ForegroundColor Green
    Write-Host ""
}

function Wait-And-Download-Apk {
    Write-Host ""
    Write-Host "⏳ Dang theo doi tien trinh build tren GitHub..." -ForegroundColor Yellow
    $startTime = Get-Date

    while ($true) {
        try {
            $headers = @{ "User-Agent" = "PowerShell-NeKoBuilder" }
            $runs = Invoke-RestMethod -Uri "$RepoApi/actions/runs?per_page=1" -Headers $headers -ErrorAction Stop
            $latestRun = $runs.workflow_runs[0]
            
            $status = $latestRun.status
            $conclusion = $latestRun.conclusion
            $elapsed = [int]((Get-Date) - $startTime).TotalSeconds

            Write-Host -NoNewline "`r[*] Trang thai: $status | Ket qua: $conclusion | Thoi gian: ${elapsed}s...   " -ForegroundColor Cyan

            if ($status -eq "completed") {
                Write-Host ""
                if ($conclusion -eq "success") {
                    Write-Host "🎉 Build thanh cong tren GitHub Actions!" -ForegroundColor Green
                    Start-Sleep -Seconds 3
                    Download-LatestRelease
                    return
                } else {
                    Write-Host "❌ Build that bai tren GitHub. Ban hay kiem tra log tai: $($latestRun.html_url)" -ForegroundColor Red
                    Pause
                    return
                }
            }
        }
        catch {
            # Bo qua loi mang nhe khi goi API
        }
        Start-Sleep -Seconds 10
    }
}

function Run-BuildAndPush {
    Show-Header
    Write-Host "[1/3] Kiem tra thay doi ma nguon..." -ForegroundColor Yellow
    Set-Location $PSScriptRoot
    
    $status = git status --porcelain
    if ($status) {
        Write-Host "Phat hien thay doi chua commit, dang them vao git..." -ForegroundColor Gray
        git add -A
        $msg = Read-Host "Nhap ghi chu cap nhat (Enter de dung mac dinh: 'update NeKo VPN')"
        if ([string]::IsNullOrWhiteSpace($msg)) { $msg = "update NeKo VPN: $(Get-Date -Format 'yyyy-MM-dd HH:mm')" }
        git commit -m $msg
    } else {
        Write-Host "Ma nguon sach se, khong co thay doi chua luu." -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "[2/3] Dang day ma nguon len GitHub..." -ForegroundColor Yellow
    git push origin main
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Khong the push code. Vui long kiem tra lai ket noi hoac quyen truy cap." -ForegroundColor Red
        Pause
        return
    }

    Write-Host "✅ Da day code len GitHub thanh cong!" -ForegroundColor Green
    Write-Host ""
    Write-Host "[3/3] He thong dang tu dong build APK..." -ForegroundColor Yellow
    Write-Host "Script se tu dong doi va tai file APK thang vao thu muc Downloads khi xong!" -ForegroundColor Magenta
    
    Wait-And-Download-Apk
}

function Download-LatestRelease {
    Show-Header
    Write-Host "Dang kiem tra file APK trong ban Release..." -ForegroundColor Yellow
    
    try {
        $headers = @{ "User-Agent" = "PowerShell-NeKoBuilder" }
        $releases = Invoke-RestMethod -Uri "$RepoApi/releases" -Headers $headers -ErrorAction Stop
        
        if (-not $releases -or $releases.Count -eq 0) {
            Write-Host "Chua tim thay ban Release nao tren repo. Mo tab Actions de tai APK thu cong:" -ForegroundColor Yellow
            Start-Process "$RepoUrl/actions"
            Pause
            return
        }

        $latestRelease = $releases[0]
        Write-Host "Phien ban: $($latestRelease.name)" -ForegroundColor Green
        $assets = $latestRelease.assets | Where-Object { $_.name -like "*.apk" }

        if (-not $assets) {
            Write-Host "Chua co file APK trong Release nay. Mo trang web de kiem tra:" -ForegroundColor Yellow
            Start-Process "$RepoUrl/actions"
            Pause
            return
        }

        $downloadedFiles = @()
        foreach ($asset in $assets) {
            $dest = Join-Path $DownloadsDir $asset.name
            Write-Host "Dang tai: $($asset.name) ($( [math]::Round($asset.size / 1MB, 2) ) MB) -> Downloads..." -ForegroundColor Cyan
            Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $dest -UserAgent "PowerShell"
            Write-Host "✅ Da luu vao: $dest" -ForegroundColor Green
            $downloadedFiles += $dest
        }

        Write-Host ""
        Write-Host "========================================================" -ForegroundColor Green
        Write-Host "🎉 HOAN TAT! File APK da duoc luu vao thu muc Tai ve (Downloads):" -ForegroundColor Yellow
        Write-Host "   $DownloadsDir" -ForegroundColor Cyan
        Write-Host "========================================================" -ForegroundColor Green
        
        # Tu dong mo thu muc Downloads va chon file APK vua tai
        if ($downloadedFiles.Count -gt 0) {
            & explorer.exe /select, "$($downloadedFiles[0])"
        } else {
            Invoke-Item $DownloadsDir
        }
    }
    catch {
        Write-Host "Loi khi tai APK tu Release: $_" -ForegroundColor Red
        Write-Host "Mo trang Actions de tai truc tiep:" -ForegroundColor Cyan
        Start-Process "$RepoUrl/actions"
    }
    Pause
}

function Install-ViaAdb {
    Show-Header
    Write-Host "Kiem tra thiet bi Android qua ADB..." -ForegroundColor Yellow
    
    if (-not (Test-Path $AdbPath)) {
        Write-Host "❌ Khong tim thay adb.exe tai: $AdbPath" -ForegroundColor Red
        Pause
        return
    }

    $devices = & $AdbPath devices
    $deviceList = $devices | Where-Object { $_ -match "\bdevice\b" -and $_ -notmatch "List of" }

    if (-not $deviceList) {
        Write-Host "⚠️ Khong tim thay dien thoai nao ket noi." -ForegroundColor Yellow
        Write-Host "Hay cam cap USB noi may tinh voi dien thoai va bat 'Go loi USB' (USB Debugging)." -ForegroundColor Gray
        Pause
        return
    }

    Write-Host "✅ Phat hien thiet bi: $($deviceList -join ', ')" -ForegroundColor Green
    
    $apks = Get-ChildItem -Path $DownloadsDir -Filter "*NeKo*.apk" -ErrorAction SilentlyContinue
    if (-not $apks) {
        $apks = Get-ChildItem -Path $DownloadsDir -Filter "*.apk" -ErrorAction SilentlyContinue
    }

    if (-not $apks) {
        Write-Host "Chua co file APK trong thu muc Downloads. Vui long chon chuc nang [2] de tai APK ve truoc." -ForegroundColor Yellow
        Pause
        return
    }

    $targetApk = $apks | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    Write-Host "Dang cai dat $($targetApk.Name) vao dien thoai..." -ForegroundColor Cyan
    & $AdbPath install -r $targetApk.FullName

    if ($LASTEXITCODE -eq 0) {
        Write-Host "🎉 Cai dat NeKo VPN len dien thoai thanh cong!" -ForegroundColor Green
    } else {
        Write-Host "❌ Cai dat that bai. Vui long kiem tra man hinh dien thoai de dong y cap quyen cai dat." -ForegroundColor Red
    }
    Pause
}

# --- MENU CHINH ---
while ($true) {
    Show-Header
    Write-Host " [1] Build APK moi (Tu dong build & Tai thang vao Downloads)" -ForegroundColor White
    Write-Host " [2] Tai APK moi nhat ve thu muc Downloads ngay" -ForegroundColor White
    Write-Host " [3] Cai dat APK tu Downloads vao dien thoai (ADB)" -ForegroundColor White
    Write-Host " [4] Mo thu muc Downloads tren may tinh" -ForegroundColor White
    Write-Host " [5] Mo trang GitHub Actions tren trinh duyet" -ForegroundColor White
    Write-Host " [0] Thoat" -ForegroundColor Gray
    Write-Host ""
    $choice = Read-Host "Chon chuc nang (0-5)"

    switch ($choice) {
        "1" { Run-BuildAndPush }
        "2" { Download-LatestRelease }
        "3" { Install-ViaAdb }
        "4" { Invoke-Item $DownloadsDir }
        "5" { Start-Process "$RepoUrl/actions" }
        "0" { exit }
        default { Write-Host "Lua chon khong hop le!" -ForegroundColor Red; Start-Sleep -Seconds 1 }
    }
}
