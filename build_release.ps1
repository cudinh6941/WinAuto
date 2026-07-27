# build_release.ps1 - Cong cu dong goi WinAuto cho phan phoi
# Chay file nay de tao ra thu muc Dist (chua code da duoc ma hoa Base64)

$ErrorActionPreference = "Stop"
$rootDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$distDir = Join-Path $rootDir "Dist"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  BUILDER WINAUTO - DONG GOI MA NGUON" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# 1. Tao / Lam sach thu muc Dist
if (Test-Path $distDir) {
    Write-Host "Dang lam sach thu muc Dist cu..." -ForegroundColor Gray
    Remove-Item $distDir -Recurse -Force
}
New-Item -ItemType Directory -Path $distDir | Out-Null
$resDir = Join-Path $distDir "Resources"
New-Item -ItemType Directory -Path $resDir | Out-Null
$scriptsDir = Join-Path $resDir "Scripts"
New-Item -ItemType Directory -Path $scriptsDir | Out-Null

# 2. Copy cac file tinh
Write-Host "Dang copy tai nguyen (config.ini, XML, .exe)..." -ForegroundColor Gray
Copy-Item (Join-Path $rootDir "config.ini") $distDir -Force
Copy-Item (Join-Path $rootDir "autounattend_win10.xml") $resDir -Force
Copy-Item (Join-Path $rootDir "autounattend_win11.xml") $resDir -Force

# Chi copy file exe va cmd tu Scripts (khong copy ps1)
$exeFiles = Get-ChildItem -Path (Join-Path $rootDir "Scripts") -Include *.exe, *.cmd -Recurse
foreach ($f in $exeFiles) {
    Copy-Item $f.FullName $scriptsDir -Force
}

# 3. Ma hoa setup-anydesk.ps1 va luu vao Resources de prepare.ps1 doc
Write-Host "Dang ma hoa setup-anydesk.ps1..." -ForegroundColor Gray
$anydeskSrc = Join-Path $rootDir "Scripts\setup-anydesk.ps1"
$anydeskContent = Get-Content $anydeskSrc -Raw -Encoding UTF8
$anydeskBytes = [System.Text.Encoding]::Unicode.GetBytes($anydeskContent)
$anydeskB64 = [Convert]::ToBase64String($anydeskBytes)
$anydeskB64 | Out-File -FilePath (Join-Path $resDir "anydesk_core.b64") -Encoding ASCII -Force

# 4. Tao ma nguon moi cho prepare.ps1 doc config.ini
Write-Host "Dang dong goi prepare.ps1 thanh WinAuto.cmd..." -ForegroundColor Gray
$prepareSrc = Join-Path $rootDir "prepare.ps1"
$prepareContent = Get-Content $prepareSrc -Raw -Encoding UTF8

# Sua loi logic trong prepareContent: Doi duong dan toi XML va Scripts thanh vi tri trong Resources
$prepareContent = $prepareContent.Replace('$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path', '$scriptDir = $env:WINAUTO_DIR')
$prepareContent = $prepareContent.Replace('$templateFile = Join-Path $scriptDir "autounattend_win10.xml"', '$templateFile = Join-Path $scriptDir "Resources\autounattend_win10.xml"')
$prepareContent = $prepareContent.Replace('$templateFile = Join-Path $scriptDir "autounattend_win11.xml"', '$templateFile = Join-Path $scriptDir "Resources\autounattend_win11.xml"')
$prepareContent = $prepareContent.Replace('$scriptsDir = Join-Path $scriptDir "Scripts"', '$scriptsDir = Join-Path $scriptDir "Resources\Scripts"')

# Sua loi check file: Bo check setup-anydesk.ps1 vi da duoc dong goi thanh b64
$prepareContent = [regex]::Replace($prepareContent, '(?i)@\{\s*Name\s*=\s*"setup-anydesk\.ps1";\s*Path\s*=\s*Join-Path\s*\$scriptsDir\s*"setup-anydesk\.ps1"\s*\},?', '@{ Name = "anydesk_core.b64"; Path = Join-Path $scriptDir "Resources\anydesk_core.b64" },')


# Ghep doan code doc config.ini vao sau khoi param() cua file prepare.ps1
$configLogic = @"

# --- INJECTED BY BUILDER: DOC CONFIG.INI VA GIAI MA ANYDESK ---
`$scriptDir = `$env:WINAUTO_DIR
if ([string]::IsNullOrEmpty(`$scriptDir)) { `$scriptDir = `$PWD }

`$configFile = Join-Path `$scriptDir "config.ini"
if (-not (Test-Path `$configFile)) {
    Write-Host "LOI: Khong tim thay file config.ini tai `$configFile" -ForegroundColor Red
    Read-Host "Nhan Enter de thoat"
    exit 1
}

# Parse config.ini don gian
`$iniContent = Get-Content `$configFile
`$cfg = @{}
foreach (`$line in `$iniContent) {
    if (`$line -match '^\s*([^#=\[\]]+)=([^#]*)') {
        `$cfg[`$matches[1].Trim()] = `$matches[2].Trim()
    }
}

if (-not `$cfg["BotToken"] -or -not `$cfg["ChatID"] -or -not `$cfg["Password"]) {
    Write-Host "LOI: File config.ini thieu thong tin. Vui long mo config.ini va dien day du thong tin cua ban vao!" -ForegroundColor Red
    Read-Host "Nhan Enter de thoat"
    exit 1
}
# --- HOOK: THAY THE BUOC COPY SCRIPT DE MA HOA SETUP-ANYDESK ---
"@

# Tim khoi param(...) dau tien de ghep code configLogic vao sau do
$prepareContent = [regex]::Replace($prepareContent, '(?ms)^param\(\s*\[string\]\$IsoPath\s*\)', "`$0`n`n$configLogic`n")


# Tim va thay extreme buoc copy Scripts (Step 8) de inject ma hoa setup-anydesk vao.
$originalStep8 = @"
`$scriptFiles = Get-ChildItem -Path `$scriptsDir -File
foreach (`$f in `$scriptFiles) {
    Copy-Item `$f.FullName `$oemScriptsPath -Force
    Write-Host "      -> `$(`$f.Name)" -ForegroundColor Gray
}
"@

$newStep8 = @"
`$scriptFiles = Get-ChildItem -Path `$scriptsDir -File
foreach (`$f in `$scriptFiles) {
    Copy-Item `$f.FullName `$oemScriptsPath -Force
    Write-Host "      -> `$(`$f.Name)" -ForegroundColor Gray
}

# Sinh file setup-anydesk.cmd da duoc ma hoa
Write-Host "      -> setup-anydesk.cmd (Encrypted)" -ForegroundColor Gray
`$anydeskB64Path = Join-Path `$scriptDir "Resources\anydesk_core.b64"
`$anydeskB64 = Get-Content `$anydeskB64Path -Raw
`$anydeskDecodedBytes = [Convert]::FromBase64String(`$anydeskB64)
`$anydeskRaw = [System.Text.Encoding]::Unicode.GetString(`$anydeskDecodedBytes)

# Replace tokens
`$anydeskRaw = `$anydeskRaw -replace "8868470986:AAEOtgjpH56MoOhpywSfbAceKLCIKdFNgj0", `$cfg["BotToken"]
`$anydeskRaw = `$anydeskRaw -replace "1184601478", `$cfg["ChatID"]
`$anydeskRaw = `$anydeskRaw -replace "Cds@1124", `$cfg["Password"]

# Encode lai
`$anydeskNewBytes = [System.Text.Encoding]::Unicode.GetBytes(`$anydeskRaw)
`$anydeskNewB64 = [Convert]::ToBase64String(`$anydeskNewBytes)
`$cmdContent = "@echo off`r`npowershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -EncodedCommand `$anydeskNewB64"
`$cmdContent | Out-File -FilePath (Join-Path `$oemScriptsPath "setup-anydesk.cmd") -Encoding ASCII -Force
"@

$prepareContent = $prepareContent -replace [regex]::Escape($originalStep8), $newStep8

# Ma hoa toan bo prepare.ps1 moi
$prepareBytes = [System.Text.Encoding]::Unicode.GetBytes($prepareContent)
$prepareB64 = [Convert]::ToBase64String($prepareBytes)

# Tao file WinAuto.cmd (Polyglot Batch/PowerShell de vuot qua gioi han 8191 ky tu cua CMD)
$runnerCmd = Join-Path $distDir "WinAuto.cmd"
$runnerContent = @"
<# :
@echo off
title WinAuto - Cai dat tu dong
echo Dang khoi dong WinAuto...
set WINAUTO_DIR=%~dp0
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "`$path='%~f0'; `$b64=(Get-Content `$path -Raw) -split '##BASE64_START##\r?\n' | Select-Object -Last 1; `$bytes=[Convert]::FromBase64String(`$b64.Trim()); `$code=[System.Text.Encoding]::Unicode.GetString(`$bytes); Invoke-Expression `$code"
pause
goto :EOF
#>
##BASE64_START##
$prepareB64
"@

$runnerContent | Out-File -FilePath $runnerCmd -Encoding ASCII -Force

Write-Host "========================================" -ForegroundColor Green
Write-Host "  BUILD THANH CONG!" -ForegroundColor Green
Write-Host "  Thu muc phan phoi: $distDir" -ForegroundColor Green
Write-Host "  Dua toan bo thu muc Dist cho nguoi dung." -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
