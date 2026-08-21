param([PSCustomObject]$State, [PSCustomObject]$Config)

. "$PSScriptRoot\..\lib\common.ps1"

Write-Log "===== BAT DAU PHASE 8: CAI KASPERSKY =====" -Level PHASE
Send-PhaseNotification -ComputerName $State.computerName -Phase 8 -Status "start" -Message "Cai Kaspersky"

$dryRun = Test-DryRun

# ==================== CHECK CO CAN CAI KHONG ====================
if (-not $State.installKaspersky) {
    Write-Log "Config: Khong cai Kaspersky (installKaspersky = false)" -Level INFO
    Skip-Phase -State $State -CurrentPhase 8 -Reason "User chon khong cai Kaspersky"
    return
}

# ==================== TIM INSTALLER ====================
$kasBatPath = $Config.kaspersky.batPath

if ([string]::IsNullOrEmpty($kasBatPath) -or -not (Test-Path $kasBatPath)) {
    Write-Log "KHONG TIM THAY Kaspersky installer tai: $kasBatPath" -Level ERROR
    Send-PhaseNotification -ComputerName $State.computerName -Phase 8 -Status "error" -Message "Thieu file Kaspersky installer"
    Complete-Phase -State $State -CurrentPhase 8 -Message "Kaspersky - thieu installer"
    return
}

Write-Log "Kaspersky installer: $kasBatPath" -Level INFO

# ==================== CAI KASPERSKY ====================
if ($dryRun) {
    Write-DryRun "SE CHAY: cmd.exe /c `"$kasBatPath`""
    Complete-Phase -State $State -CurrentPhase 8 -Message "[DRY-RUN] Kaspersky"
    return
}

Write-Log "Dang cai Kaspersky (co the mat 5-10 phut)..." -Level INFO

try {
    $proc = Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$kasBatPath`"" -Wait -NoNewWindow -PassThru
    
    if ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq 3010) {
        Write-Log "Cai Kaspersky thanh cong! (Exit: $($proc.ExitCode))" -Level OK
    } else {
        Write-Log "Kaspersky exit code: $($proc.ExitCode)" -Level WARN
    }
} catch {
    Write-Log "Loi khi cai Kaspersky: $($_.Exception.Message)" -Level ERROR
    Send-PhaseNotification -ComputerName $State.computerName -Phase 8 -Status "error" -Message "Loi cai Kaspersky: $($_.Exception.Message)"
}

Complete-Phase -State $State -CurrentPhase 8 -Message "Kaspersky installed"
