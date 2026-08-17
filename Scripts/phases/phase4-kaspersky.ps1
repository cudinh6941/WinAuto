# ================================================================
# Phase 4: BitLocker OFF + Cai Kaspersky (tuy chon)
# ================================================================
param([PSCustomObject]$State, [PSCustomObject]$Config)

$phaseNum = 4
Write-Log "===== PHASE $phaseNum: BITLOCKER OFF + KASPERSKY =====" -Level PHASE

# ==================== KIEM TRA CO CAN CAI KASPERSKY KHONG ====================
if (-not $State.installKaspersky) {
    Skip-Phase -State $State -CurrentPhase $phaseNum -Reason "Kaspersky khong can cai (config)"
    return
}

# ==================== BUOC 4a: MANAGE-BDE OFF TAT CA O DIA ====================
Write-Log "BitLocker: Tat ma hoa tren tat ca cac o dia..." -Level INFO

$volumes = Get-BitLockerVolume -ErrorAction SilentlyContinue

if ($volumes) {
    foreach ($vol in $volumes) {
        $mountPoint = $vol.MountPoint
        $status = $vol.ProtectionStatus
        $encPercent = $vol.EncryptionPercentage
        
        Write-Log "BitLocker: $mountPoint - Protection: $status, Encrypted: ${encPercent}%" -Level INFO
        
        if ($status -eq "On" -or $encPercent -gt 0) {
            Write-Log "BitLocker: Dang tat ma hoa cho $mountPoint..." -Level INFO
            try {
                Disable-BitLocker -MountPoint $mountPoint -ErrorAction Stop
                Write-Log "BitLocker: Da gui lenh tat cho $mountPoint" -Level OK
            } catch {
                # Fallback: manage-bde
                Write-Log "BitLocker: Disable-BitLocker that bai, thu manage-bde..." -Level WARN
                $result = manage-bde -off $mountPoint 2>&1
                Write-Log "BitLocker: manage-bde -off ${mountPoint}: $result" -Level INFO
            }
        } else {
            Write-Log "BitLocker: $mountPoint da tat ma hoa" -Level OK
        }
    }
    
    # ==================== CHO DECRYPT HOAN TAT ====================
    Write-Log "BitLocker: Cho giai ma hoan tat (co the mat vai phut)..." -Level INFO
    
    $maxWaitMinutes = 30
    $waitSeconds = 0
    $allDecrypted = $false
    
    while (-not $allDecrypted -and $waitSeconds -lt ($maxWaitMinutes * 60)) {
        $allDecrypted = $true
        $volumes = Get-BitLockerVolume -ErrorAction SilentlyContinue
        
        foreach ($vol in $volumes) {
            if ($vol.EncryptionPercentage -gt 0) {
                $allDecrypted = $false
                Write-Log "BitLocker: $($vol.MountPoint) dang giai ma... ($($vol.EncryptionPercentage)% con lai)" -Level INFO
                break
            }
        }
        
        if (-not $allDecrypted) {
            Start-Sleep -Seconds 30
            $waitSeconds += 30
        }
    }
    
    if ($allDecrypted) {
        Write-Log "BitLocker: Tat ca o dia da giai ma xong!" -Level OK
    } else {
        Write-Log "BitLocker: Qua $maxWaitMinutes phut, tiep tuc cai Kaspersky..." -Level WARN
    }
} else {
    Write-Log "BitLocker: Khong tim thay o dia nao duoc ma hoa" -Level OK
}

# ==================== BUOC 4b: CAI KASPERSKY ====================
$batPath = $Config.kaspersky.batPath

if ([string]::IsNullOrEmpty($batPath) -or -not (Test-Path $batPath)) {
    Write-Log "Kaspersky: Khong tim thay file .bat tai $batPath" -Level ERROR
    Complete-Phase -State $State -CurrentPhase $phaseNum -Message "Kaspersky .bat not found"
    return
}

Write-Log "Kaspersky: Dang cai dat tu $batPath..." -Level INFO

try {
    Unblock-File -Path $batPath -ErrorAction SilentlyContinue
    
    # Chay .bat duoi quyen admin
    $proc = Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$batPath`"" `
        -Wait -PassThru -WindowStyle Normal -Verb RunAs
    
    Write-Log "Kaspersky: Cai dat xong! Exit code: $($proc.ExitCode)" -Level OK
} catch {
    Write-Log "Kaspersky: Loi cai dat - $($_.Exception.Message)" -Level ERROR
}

# Cho Kaspersky khoi dong va bat dau update
Write-Log "Kaspersky: Cho Kaspersky khoi dong va update (120s)..." -Level INFO
Start-Sleep -Seconds 120

# ==================== HOAN TAT ====================
# Kaspersky sau khi apply license se yeu cau restart
# Test-PendingReboot se detect va tu restart
Complete-Phase -State $State -CurrentPhase $phaseNum -Message "BitLocker OFF + Kaspersky installed"
