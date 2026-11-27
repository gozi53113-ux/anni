# =====================================================================
#             NeKo VPN - Cong cu Build & Quan ly APK
# =====================================================================
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$Host.UI.RawUI.WindowTitle = "NeKo VPN Builder"

$RepoUrl = "https://github.com/gozi53113-ux/anni"
$RepoApi = "https://api.github.com/repos/gozi53113-ux/anni"
$OutputDir = Join-Path $PSScriptRoot "output"
$AdbPath = "D:\AndroidROM\AndroidSDK\platform-tools\adb.exe"

function Show-Header {
    Clear-Host
    Write-Host "======================================================" -ForegroundColor Cyan
    Write-Host "             🐾 NeKo VPN Builder (PowerShell)          " -ForegroundColor Yellow
    Write-Host "======================================================" -ForegroundColor Cyan
    Write-Host " Kho luu tru: $RepoUrl" -ForegroundColor Gray
    Write-Host ""
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

    Write-Host ""
    Write-Host "✅ Da day code len GitHub thanh cong!" -ForegroundColor Green
    Write-Host "[3/3] He thong GitHub Actions dang tu dong build APK..." -ForegroundColor Yellow
    Write-Host "Ban co the theo doi truc tiep tien trinh build tai:" -ForegroundColor Cyan
    Write-Host "$RepoUrl/actions" -ForegroundColor White
    Write-Host ""
    
    $openWeb = Read-Host "Ban co muon mo trang GitHub Actions tren trinh duyet khong? (Y/N)"
    if ($openWeb -eq "Y" -or $openWeb -eq "y" -or $openWeb -eq "") {
        Start-Process "$RepoUrl/actions"
    }
}

function Download-LatestRelease {
    Show-Header
    Write-Host "Dang kiem tra ban phat hanh (Release) moi nhat..." -ForegroundColor Yellow
    
    if (-not (Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    }

    try {
        $headers = @{ "User-Agent" = "PowerShell-NeKoBuilder" }
        $release = Invoke-RestMethod -Uri "$RepoApi/releases/latest" -Headers $headers -ErrorAction Stop
        
        Write-Host "Tim thay phien ban: $($release.name)" -ForegroundColor Green
        $assets = $release.assets | Where-Object { $_.name -like "*.apk" }

        if (-not $assets) {
            Write-Host "Chua tim thay file APK trong Release. Ban hay kiem tra trong tab Actions nhe:" -ForegroundColor Yellow
            Write-Host "$RepoUrl/actions" -ForegroundColor Cyan
            Pause
            return
        }

        foreach ($asset in $assets) {
            $dest = Join-Path $OutputDir $asset.name
            Write-Host "Dang tai ve: $($asset.name) ($( [math]::Round($asset.size / 1MB, 2) ) MB)..." -ForegroundColor Cyan
            Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $dest -UserAgent "PowerShell"
            Write-Host "✅ Da tai xong: $dest" -ForegroundColor Green
        }

        Write-Host ""
        Write-Host "Mo thu muc chua APK..." -ForegroundColor Yellow
        Invoke-Item $OutputDir
    }
    catch {
        Write-Host "Chua co ban Release cong khai hoac can tai tu tab Actions." -ForegroundColor Yellow
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
    
    $apks = Get-ChildItem -Path $OutputDir -Filter "*.apk" -ErrorAction SilentlyContinue
    if (-not $apks) {
        Write-Host "Chua co file APK trong thu muc output. Vui long chon chuc nang [2] de tai APK ve truoc." -ForegroundColor Yellow
        Pause
        return
    }

    $targetApk = $apks | Select-Object -First 1
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
    Write-Host " [1] Build APK moi (Commit, Push code va kich hoat build)" -ForegroundColor White
    Write-Host " [2] Tai APK moi nhat ve may tinh (Thu muc output)" -ForegroundColor White
    Write-Host " [3] Cai dat APK vao dien thoai qua cap USB (ADB)" -ForegroundColor White
    Write-Host " [4] Mo trang theo doi build tren GitHub Actions" -ForegroundColor White
    Write-Host " [0] Thoat" -ForegroundColor Gray
    Write-Host ""
    $choice = Read-Host "Chon chuc nang (0-4)"

    switch ($choice) {
        "1" { Run-BuildAndPush }
        "2" { Download-LatestRelease }
        "3" { Install-ViaAdb }
        "4" { Start-Process "$RepoUrl/actions" }
        "0" { exit }
        default { Write-Host "Lua chon khong hop le!" -ForegroundColor Red; Start-Sleep -Seconds 1 }
    }
}
