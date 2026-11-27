# Tao keystore co dinh cho NeKo VPN va cac gia tri de them vao GitHub Secrets.
# Chay:  powershell -ExecutionPolicy Bypass -File tools/create-keystore.ps1
#
# File tao ra (da nam trong .gitignore, KHONG commit):
#   keys/neko-release.jks     - private signing key, phai backup
#   keys/keystore-info.txt    - alias + mat khau
#   keys/keystore.b64         - base64 de dan vao secret APP_KEYSTORE_BASE64
#   keys/github-secrets.txt   - 4 secret can them vao repo
param(
    [switch]$Force,
    [string]$Alias = "neko"
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$keysDir = Join-Path $repoRoot "keys"
$jks = Join-Path $keysDir "neko-release.jks"

if ((Test-Path $jks) -and -not $Force) {
    Write-Host "Keystore da ton tai: $jks"
    Write-Host "Dung -Force neu ban that su muon tao lai (se lam ban cap nhat cu khong cai de duoc)."
    exit 1
}

New-Item -ItemType Directory -Force -Path $keysDir | Out-Null

$keytool = "keytool"
if ($env:JAVA_HOME) {
    $candidate = Join-Path $env:JAVA_HOME "bin\keytool.exe"
    if (Test-Path $candidate) { $keytool = $candidate }
}

# Mat khau chi gom chu + so de truyen qua Gradle/bash an toan.
$chars = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789"
$pass = -join (1..32 | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })

& $keytool -genkeypair `
    -keystore $jks `
    -alias $Alias `
    -keyalg RSA `
    -keysize 4096 `
    -validity 10000 `
    -storepass $pass `
    -keypass $pass `
    -dname "CN=NeKo VPN, OU=NeKo VPN, O=NeKo VPN, L=Hanoi, ST=Hanoi, C=VN"

if ($LASTEXITCODE -ne 0) { throw "keytool failed with exit code $LASTEXITCODE" }

$b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($jks))
Set-Content -Path (Join-Path $keysDir "keystore.b64") -Value $b64 -Encoding ASCII
Set-Content -Path (Join-Path $keysDir "keystore-info.txt") -Encoding UTF8 -Value @(
    "Keystore : $jks",
    "Alias    : $Alias",
    "StorePass: $pass",
    "KeyPass  : $pass",
    "",
    "Backup file .jks va mat khau nay. Mat keystore = khong the cap nhat app da cai."
)

$secretFile = @"
# Dan 4 gia tri nay vao GitHub > Settings > Secrets and variables > Actions
# hoac dung gh CLI (xem cuoi file).

APP_KEYSTORE_ALIAS=$Alias
APP_KEYSTORE_PASSWORD=$pass
APP_KEY_PASSWORD=$pass

# APP_KEYSTORE_BASE64 dai, lay tu file keys/keystore.b64
# (mo file bang Notepad, copy toan bo noi dung, khong xuong dong).

# --- gh CLI ---
# gh auth login
# gh secret set APP_KEYSTORE_BASE64   --repo gozi53113-ux/anni < keys/keystore.b64
# gh secret set APP_KEYSTORE_ALIAS    --repo gozi53113-ux/anni --body "$Alias"
# gh secret set APP_KEYSTORE_PASSWORD --repo gozi53113-ux/anni --body "$pass"
# gh secret set APP_KEY_PASSWORD      --repo gozi53113-ux/anni --body "$pass"
"@
Set-Content -Path (Join-Path $keysDir "github-secrets.txt") -Value $secretFile -Encoding UTF8

Write-Host ""
Write-Host "Da tao xong:"
Write-Host "  $jks"
Write-Host "  $keysDir\keystore-info.txt"
Write-Host "  $keysDir\keystore.b64"
Write-Host "  $keysDir\github-secrets.txt"
Write-Host ""
Write-Host "Backup thu muc keys/ ngay bay gio. Khong commit thu muc nay."
