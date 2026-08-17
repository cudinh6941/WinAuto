# ================================================================
# Phase 8: Hoan tat - Switch sang domain user + Don dep
# ================================================================
param([PSCustomObject]$State, [PSCustomObject]$Config)

$phaseNum = 9
Write-Log "===== PHASE $phaseNum: HOAN TAT + SWITCH USER =====" -Level PHASE

$domainName = $Config.domain.name
$netbiosDomain = $domainName.Split('.')[0]
$domainUsername = $State.domainUsername
$domainUserPassword = Unprotect-Secret $State.domainUserPassword
$computerName = $State.computerName

# ==================== XOA AUTO-LOGON CU ====================
Write-Log "Xoa auto-logon Administrator..." -Level INFO

$winlogonPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"

# ==================== SET AUTO-LOGON DOMAIN USER ====================
Write-Log "Set auto-logon cho $netbiosDomain\$domainUsername..." -Level INFO

try {
    Set-ItemProperty -Path $winlogonPath -Name "AutoAdminLogon" -Value "1" -Force
    Set-ItemProperty -Path $winlogonPath -Name "DefaultDomainName" -Value $netbiosDomain -Force
    Set-ItemProperty -Path $winlogonPath -Name "DefaultUserName" -Value $domainUsername -Force
    Set-ItemProperty -Path $winlogonPath -Name "DefaultPassword" -Value $domainUserPassword -Force
    Write-Log "Auto-logon da set cho $netbiosDomain\$domainUsername" -Level OK
} catch {
    Write-Log "Set auto-logon that bai: $($_.Exception.Message)" -Level ERROR
}

# ==================== TAO SCRIPT DON DEP SAU LOGIN ====================
# Script nay chay 1 lan sau khi domain user login, de:
# 1. Xoa auto-logon (bao mat)
# 2. Xoa scheduled task
# 3. Xoa state.json
$cleanupScript = @'
# WinAuto Cleanup - Chay 1 lan sau khi domain user login
Start-Sleep -Seconds 10

# Xoa auto-logon password
$winlogonPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
Set-ItemProperty -Path $winlogonPath -Name "AutoAdminLogon" -Value "0" -Force
Remove-ItemProperty -Path $winlogonPath -Name "DefaultPassword" -Force -ErrorAction SilentlyContinue

# Xoa scheduled tasks
Unregister-ScheduledTask -TaskName "WinAuto_Resume" -Confirm:$false -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName "WinAuto_Cleanup" -Confirm:$false -ErrorAction SilentlyContinue

# Xoa state.json (chua thong tin nhay cam)
$stateFile = "D:\WinAuto\state.json"
if (Test-Path $stateFile) { Remove-Item $stateFile -Force }

# Xoa chinh minh
$selfPath = $MyInvocation.MyCommand.Path
if ($selfPath) {
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c timeout /t 5 & del `"$selfPath`"" -WindowStyle Hidden
}
'@

$cleanupPath = Join-Path $script:WinAutoRoot "Scripts\cleanup.ps1"
$cleanupScript | Out-File -FilePath $cleanupPath -Encoding UTF8 -Force
Write-Log "Da tao script don dep: $cleanupPath" -Level OK

# Tao Scheduled Task cho cleanup (chay khi domain user login)
$cleanupAction = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$cleanupPath`""
$cleanupTrigger = New-ScheduledTaskTrigger -AtLogOn -User "$netbiosDomain\$domainUsername"
$cleanupTrigger.Delay = "PT15S"
$cleanupSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
$cleanupPrincipal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest

Register-ScheduledTask -TaskName "WinAuto_Cleanup" `
    -Action $cleanupAction `
    -Trigger $cleanupTrigger `
    -Settings $cleanupSettings `
    -Principal $cleanupPrincipal `
    -Description "WinAuto - Don dep sau khi domain user login" `
    -Force | Out-Null

Write-Log "Scheduled Task 'WinAuto_Cleanup' da duoc tao" -Level OK

# ==================== XOA WINAUTO RESUME TASK ====================
Unregister-WinAutoTask

# ==================== GUI TELEGRAM ====================
if ($Config.telegram -and $Config.telegram.enabled) {
    $currentTime = Get-Date -Format "dd/MM/yyyy HH:mm"
    $startTime = $State.startTime
    
    # Tinh thoi gian
    $elapsed = ""
    try {
        $start = [DateTime]::ParseExact($startTime, "yyyy-MM-dd HH:mm:ss", $null)
        $diff = (Get-Date) - $start
        $elapsed = "$([math]::Floor($diff.TotalMinutes)) phut"
    } catch { }
    
    $message = "<b>✅ May tinh da cai xong!</b>`n" +
               "Ten may: <code>$computerName</code>`n" +
               "Domain user: <code>$netbiosDomain\$domainUsername</code>`n" +
               "Kaspersky: $(if ($State.installKaspersky) {'Co'} else {'Khong'})`n" +
               "Office: $($State.officeType)`n" +
               "Thoi gian: $currentTime`n" +
               "Tong thoi gian: $elapsed"
    
    Send-TelegramMessage -Message $message `
        -BotToken $Config.telegram.botToken `
        -ChatId $Config.telegram.chatId
}

# ==================== GHI LOG TONG KET ====================
Write-Log "==========================================" -Level PHASE
Write-Log "HOAN TAT CAI DAT WINAUTO v2" -Level PHASE
Write-Log "Computer: $computerName" -Level PHASE
Write-Log "Domain User: $netbiosDomain\$domainUsername" -Level PHASE
Write-Log "Kaspersky: $(if ($State.installKaspersky) {'Da cai'} else {'Khong cai'})" -Level PHASE
Write-Log "Office: $($State.officeType)" -Level PHASE
Write-Log "Bat dau: $($State.startTime)" -Level PHASE
Write-Log "Ket thuc: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -Level PHASE
Write-Log "==========================================" -Level PHASE

# ==================== PHASE LOG ====================
Write-Log "Chi tiet cac phase:" -Level INFO
foreach ($log in $State.phaseLog) {
    Write-Log "  Phase $($log.phase): $($log.status) ($($log.time)) - $($log.message)" -Level INFO
}

# ==================== RESTART LAN CUOI ====================
Write-Log "Restart lan cuoi de login vao domain user..." -Level WARN
Start-Sleep -Seconds 5
Restart-Computer -Force
Start-Sleep -Seconds 60
