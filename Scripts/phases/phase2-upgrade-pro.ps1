param([PSCustomObject]$State, [PSCustomObject]$Config)

. "$PSScriptRoot\..\lib\common.ps1"

Write-Log "===== BAT DAU PHASE 2: UPGRADE WIN HOME -> PRO =====" -Level PHASE
Send-PhaseNotification -ComputerName $State.computerName -Phase 2 -Status "start" -Message "Upgrade len Windows Pro"

$dryRun = Test-DryRun

# ==================== CHECK EDITION HIEN TAI ====================
$currentEdition = (Get-WindowsEdition -Online).Edition
Write-Log "Edition hien tai: $currentEdition" -Level INFO

if ($currentEdition -match "Pro|Enterprise|Education") {
    Write-Log "Da la ban $currentEdition - BO QUA upgrade" -Level OK
    Skip-Phase -State $State -CurrentPhase 2 -Reason "Da la Windows $currentEdition"
    return
}

# ==================== LAY PRODUCT KEY ====================
$proKey = if ($State.winVersion -eq "11") {
    $Config.upgrade.win11ProKey
} else {
    $Config.upgrade.win10ProKey
}

if ([string]::IsNullOrEmpty($proKey)) {
    Write-Log "Khong co product key trong config.json!" -Level ERROR
    Skip-Phase -State $State -CurrentPhase 2 -Reason "Thieu product key"
    return
}

Write-Log "Dang upgrade len Pro voi key: $($proKey.Substring(0,5))..." -Level INFO

if ($dryRun) {
    Write-DryRun "SE CHAY: changepk.exe /ProductKey $($proKey.Substring(0,5))..."
    Write-DryRun "SE CHAY: DISM /Online /Set-Edition:Professional /AcceptEula"
    Complete-Phase -State $State -CurrentPhase 2 -Message "[DRY-RUN] Upgrade Pro"
    return
}

# ==================== UPGRADE ====================
try {
    # Phuong phap 1: changepk.exe (nhanh, Windows 10/11)
    $changepk = "$env:SystemRoot\System32\changepk.exe"
    if (Test-Path $changepk) {
        Write-Log "Dung changepk.exe de upgrade..." -Level INFO
        Start-Process -FilePath $changepk -ArgumentList "/ProductKey $proKey" -Wait -NoNewWindow
        Start-Sleep -Seconds 10
    } else {
        # Phuong phap 2: DISM
        Write-Log "changepk khong co, dung DISM de upgrade..." -Level INFO
        $dismArgs = "/Online /Set-Edition:Professional /ProductKey:$proKey /AcceptEula /Quiet /NoRestart"
        $proc = Start-Process -FilePath "DISM.exe" -ArgumentList $dismArgs -Wait -NoNewWindow -PassThru
        Write-Log "DISM exit code: $($proc.ExitCode)" -Level INFO
    }
    
    # Verify upgrade
    Start-Sleep -Seconds 5
    $newEdition = (Get-WindowsEdition -Online).Edition
    Write-Log "Edition sau upgrade: $newEdition" -Level INFO
    
    if ($newEdition -match "Pro") {
        Write-Log "Upgrade len Pro thanh cong!" -Level OK
    } else {
        Write-Log "Edition van la $newEdition - co the can restart" -Level WARN
    }
} catch {
    Write-Log "Loi khi upgrade: $($_.Exception.Message)" -Level ERROR
}

Complete-Phase -State $State -CurrentPhase 2 -Message "Upgrade Pro hoan tat (Edition: $newEdition)"
