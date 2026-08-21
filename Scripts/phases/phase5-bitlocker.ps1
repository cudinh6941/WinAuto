param([PSCustomObject]$State, [PSCustomObject]$Config)

. "$PSScriptRoot\..\lib\common.ps1"

Write-Log "===== BAT DAU PHASE 5: TAT BITLOCKER =====" -Level PHASE
Send-PhaseNotification -ComputerName $State.computerName -Phase 5 -Status "start" -Message "Kiem tra va tat BitLocker"

$dryRun = Test-DryRun

# ==================== CHECK BITLOCKER STATUS ====================
try {
    $blVolumes = Get-BitLockerVolume -ErrorAction Stop
    $encryptedVolumes = $blVolumes | Where-Object { 
        $_.ProtectionStatus -eq "On" -or $_.VolumeStatus -match "Encrypted|Encrypting" 
    }
    
    if ($encryptedVolumes.Count -eq 0) {
        Write-Log "BitLocker chua bat tren bat ky o nao - BO QUA" -Level OK
        Skip-Phase -State $State -CurrentPhase 5 -Reason "BitLocker chua bat"
        return
    }
    
    Write-Log "Tim thay $($encryptedVolumes.Count) o dang encrypt:" -Level INFO
    foreach ($vol in $encryptedVolumes) {
        Write-Log "  O $($vol.MountPoint): $($vol.VolumeStatus), Protection: $($vol.ProtectionStatus)" -Level INFO
    }
    
} catch {
    # Get-BitLockerVolume khong ton tai tren Home edition
    Write-Log "Khong truy cap duoc BitLocker (co the la Home edition): $($_.Exception.Message)" -Level INFO
    Skip-Phase -State $State -CurrentPhase 5 -Reason "BitLocker khong kha dung"
    return
}

# ==================== TAT BITLOCKER ====================
foreach ($vol in $encryptedVolumes) {
    $mountPoint = $vol.MountPoint
    Write-Log "Dang tat BitLocker tren $mountPoint..." -Level INFO
    
    if ($dryRun) {
        Write-DryRun "SE CHAY: Disable-BitLocker -MountPoint $mountPoint"
        continue
    }
    
    try {
        Disable-BitLocker -MountPoint $mountPoint -ErrorAction Stop
        Write-Log "Da tat BitLocker tren $mountPoint" -Level OK
    } catch {
        Write-Log "Loi tat BitLocker tren ${mountPoint}: $($_.Exception.Message)" -Level ERROR
        
        # Thu suspend truoc
        try {
            Suspend-BitLocker -MountPoint $mountPoint -RebootCount 0 -ErrorAction Stop
            Write-Log "Da SUSPEND BitLocker tren $mountPoint (tam thoi)" -Level WARN
        } catch {
            Write-Log "Khong the suspend BitLocker: $($_.Exception.Message)" -Level ERROR
        }
    }
}

# Cho decrypt (co the mat vai phut)
if (-not $dryRun -and $encryptedVolumes.Count -gt 0) {
    Write-Log "Cho decryption bat dau (30s)..." -Level INFO
    Start-Sleep -Seconds 30
    
    # Check lai trang thai
    $blCheck = Get-BitLockerVolume -MountPoint "C:" -ErrorAction SilentlyContinue
    if ($blCheck) {
        Write-Log "C: Volume Status: $($blCheck.VolumeStatus), Protection: $($blCheck.ProtectionStatus)" -Level INFO
    }
}

Complete-Phase -State $State -CurrentPhase 5 -Message "BitLocker da tat/suspend"
