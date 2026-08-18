$ErrorActionPreference = "Stop"
$cwd = "d:\WinAuto"
$scriptsDir = "$cwd\Scripts"
$phasesDir = "$scriptsDir\phases"
$phasesBackup = "$scriptsDir\phases_backup"
$commonPs1 = "$scriptsDir\lib\common.ps1"
$commonBackup = "$scriptsDir\lib\common_backup.ps1"
$stateFile = "$cwd\state.json"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "   MOCK TEST WINAUTO (KHONG CAN CAI WIN)  " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# 1. Backup
if (Test-Path $phasesBackup) { Remove-Item $phasesBackup -Recurse -Force }
Copy-Item $phasesDir $phasesBackup -Recurse -Force
Copy-Item $commonPs1 $commonBackup -Force
Write-Host "[+] Da sao luu code that."

# 2. Ngăn chặn Restart-Computer trong common.ps1
$commonContent = Get-Content $commonPs1 -Raw
$commonContent = $commonContent -replace "Restart-Computer -Force", "Write-Host '   [MOCK] Da chan lenh Restart-Computer' -ForegroundColor Magenta"
$commonContent = $commonContent -replace "Start-Sleep -Seconds 60", "Start-Sleep -Seconds 1"
$commonContent | Out-File $commonPs1 -Encoding UTF8

# 3. Tao state.json
$stateJson = @"
{
    "currentPhase": 1,
    "computerName": "TEST-PC",
    "domainUsername": "admin",
    "domainUserPassword": "",
    "winVersion": "10",
    "installKaspersky": true,
    "officeType": "365",
    "domainJoinAccount": "join",
    "domainJoinPassword": "",
    "startTime": "2026-08-18 12:00:00",
    "phaseLog": []
}
"@
$stateJson | Out-File $stateFile -Encoding UTF8
Write-Host "[+] Da tao state.json gia lap."

# 4. Ghi de phase scripts thanh ban in ra log
for ($i = 1; $i -le 9; $i++) {
    $mockScript = @"
param([PSCustomObject]`$State, [PSCustomObject]`$Config)
Write-Host "   >>> DANG CHAY PHASE $i GIA LAP <<<" -ForegroundColor Green
Start-Sleep -Seconds 1
. "`$PSScriptRoot\..\lib\common.ps1"
Complete-Phase -State `$State -CurrentPhase $i -Message "Mock phase $i hoan tat"
"@
    $files = Get-ChildItem -Path $phasesDir -Filter "phase$i-*.ps1"
    if ($files.Count -gt 0) {
        $mockScript | Out-File $files[0].FullName -Encoding UTF8
    }
}
Write-Host "[+] Da vo hieu hoa cac script phase (an toan cho may)."

Write-Host "`n==========================================" -ForegroundColor Yellow
Write-Host "   KHOI CHAY POST-INSTALL.PS1...          " -ForegroundColor Yellow
Write-Host "==========================================`n"

# Chay post-install (Bypass thoi gian cho 20s de test cho nhanh)
$postInstallPath = "$scriptsDir\post-install.ps1"
$postInstallContent = Get-Content $postInstallPath -Raw
$postInstallContent = $postInstallContent -replace "Start-Sleep -Seconds 20", "Start-Sleep -Seconds 1"
$postInstallContent | Out-File $postInstallPath -Encoding UTF8

# Execute
& $postInstallPath

# Restore post-install
$postInstallContent = $postInstallContent -replace "Start-Sleep -Seconds 1", "Start-Sleep -Seconds 20"
$postInstallContent | Out-File $postInstallPath -Encoding UTF8

Write-Host "`n==========================================" -ForegroundColor Cyan
Write-Host "   HOAN TAT TEST - KHOI PHUC TRANG THAI   " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# 5. Restore
Remove-Item $stateFile -Force
Remove-Item $phasesDir -Recurse -Force
Rename-Item $phasesBackup "phases"
Copy-Item $commonBackup $commonPs1 -Force
Remove-Item $commonBackup -Force
Write-Host "[+] Da khoi phuc tra lai code nhu cu!"
