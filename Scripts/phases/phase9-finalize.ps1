param([PSCustomObject]$State, [PSCustomObject]$Config)

. "$PSScriptRoot\..\lib\common.ps1"

Write-Log "===== BAT DAU PHASE 9: FINALIZE =====" -Level PHASE
Send-PhaseNotification -ComputerName $State.computerName -Phase 9 -Status "start" -Message "Hoan tat cai dat"

$dryRun = Test-DryRun
$domainName = $Config.domain.name
$domainUser = $State.domainUsername

# ==================== XOA SCHEDULED TASK ====================
Write-Log "Xoa Scheduled Task WinAuto_Resume..." -Level INFO
if ($dryRun) {
    Write-DryRun "SE XOA: Scheduled Task WinAuto_Resume"
} else {
    Unregister-WinAutoTask
}

# ==================== XOA AUTO-LOGON REGISTRY ====================
Write-Log "Xoa Auto-Logon registry keys..." -Level INFO
if ($dryRun) {
    Write-DryRun "SE XOA: HKLM:\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Winlogon auto-logon keys"
} else {
    $winlogonPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
    try {
        Set-ItemProperty -Path $winlogonPath -Name "AutoAdminLogon" -Value "0" -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $winlogonPath -Name "DefaultUserName" -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $winlogonPath -Name "DefaultPassword" -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $winlogonPath -Name "DefaultDomainName" -ErrorAction SilentlyContinue
        Write-Log "Da xoa Auto-Logon keys" -Level OK
    } catch {
        Write-Log "Loi xoa auto-logon: $($_.Exception.Message)" -Level WARN
    }
}

# ==================== SET DEFAULT USER LOGIN ====================
if (-not [string]::IsNullOrEmpty($domainUser) -and -not [string]::IsNullOrEmpty($domainName)) {
    Write-Log "Set default login user: $domainName\\$domainUser" -Level INFO
    if ($dryRun) {
        Write-DryRun "SE SET: Default user = $domainName\\$domainUser"
    } else {
        $winlogonPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
        try {
            Set-ItemProperty -Path $winlogonPath -Name "DefaultUserName" -Value $domainUser -ErrorAction Stop
            Set-ItemProperty -Path $winlogonPath -Name "DefaultDomainName" -Value $domainName -ErrorAction Stop
            # KHONG set AutoAdminLogon = 1, chi set default user de hien tren login screen
            Write-Log "Da set default user" -Level OK
        } catch {
            Write-Log "Loi set default user: $($_.Exception.Message)" -Level WARN
        }
    }
}

# ==================== XOA STATE.JSON (BAO MAT) ====================
Write-Log "Xoa state.json (bao mat - chua password encrypted)..." -Level INFO
if ($dryRun) {
    Write-DryRun "SE XOA: $($script:StateFile)"
} else {
    if (Test-Path $script:StateFile) {
        Remove-Item $script:StateFile -Force -ErrorAction SilentlyContinue
        Write-Log "Da xoa state.json" -Level OK
    }
}

# ==================== GUI TELEGRAM THONG BAO HOAN TAT ====================
$endTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$totalMessage = @"
🎉 <b>CAI DAT HOAN TAT!</b>

💻 May: <b>$($State.computerName)</b>
🌐 Domain: $domainName
👤 User: $domainUser
🪟 Windows: $($State.winVersion)
📎 Office: $($State.officeType)
🛡️ Kaspersky: $(if ($State.installKaspersky) {'Co'} else {'Khong'})
🕐 Hoan tat luc: $endTime

May se restart lan cuoi de login vao domain user.
"@

if ($dryRun) {
    Write-DryRun "SE GUI TELEGRAM: Thong bao hoan tat"
    Write-Log $totalMessage -Level INFO
} else {
    $cfg = Get-WinAutoConfig
    if ($cfg -and $cfg.telegram -and $cfg.telegram.enabled) {
        Send-TelegramMessage -Message $totalMessage -BotToken $cfg.telegram.botToken -ChatId $cfg.telegram.chatId
    }
}

Write-Log "==========================================" -Level PHASE
Write-Log "     WINAUTO v2 - HOAN TAT THANH CONG     " -Level PHASE
Write-Log "==========================================" -Level PHASE

# ==================== RESTART LAN CUOI ====================
if ($dryRun) {
    Write-DryRun "SE RESTART may lan cuoi"
} else {
    Write-Log "Restart lan cuoi trong 10 giay..." -Level INFO
    Start-Sleep -Seconds 10
    Restart-Computer -Force
}
