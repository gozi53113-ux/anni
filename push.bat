@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo ==============================================
echo   Dang day ma nguon NeKo VPN len GitHub...
echo ==============================================
git push -u origin main
if errorlevel 1 (
  echo.
  echo Push that bai. Hay dang nhap GitHub bang: gh auth login
  echo hoac mo Git Credential Manager de dang nhap lai.
)
pause
