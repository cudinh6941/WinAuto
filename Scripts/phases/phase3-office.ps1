# ================================================================
# Phase 3: Cai Office (365 hoac 2016)
# ================================================================
param([PSCustomObject]$State, [PSCustomObject]$Config)

$phaseNum = 3
Write-Log "===== PHASE $phaseNum: CAI OFFICE ($($State.officeType)) =====" -Level PHASE

$officeType = $State.officeType

if ($officeType -eq "365") {
    # ==================== OFFICE 365 ====================
    $installerPath = $Config.office."365".installerPath
    
    if ([string]::IsNullOrEmpty($installerPath) -or -not (Test-Path $installerPath)) {
        Write-Log "Office 365: Khong tim thay installer tai $installerPath" -Level ERROR
        Complete-Phase -State $State -CurrentPhase $phaseNum -Message "Office 365 installer not found"
        return
    }
    
    Write-Log "Office 365: Dang cai dat tu $installerPath..." -Level INFO
    Unblock-File -Path $installerPath -ErrorAction SilentlyContinue
    
    try {
        $proc = Start-Process -FilePath $installerPath -PassThru
        Write-Log "Office 365: Dang cho cai dat hoan tat (co the mat 10-20 phut)..." -Level INFO
        $proc | Wait-Process -Timeout 2400 -ErrorAction SilentlyContinue
        
        if ($proc.HasExited) {
            Write-Log "Office 365: Cai dat xong! Exit code: $($proc.ExitCode)" -Level OK
        } else {
            Write-Log "Office 365: Qua 40 phut, bo qua cho..." -Level WARN
        }
    } catch {
        Write-Log "Office 365: Loi cai dat - $($_.Exception.Message)" -Level ERROR
    }
    
} elseif ($officeType -eq "2016") {
    # ==================== OFFICE 2016 (TU ISO) ====================
    $isoPath = $Config.office."2016".isoPath
    
    if ([string]::IsNullOrEmpty($isoPath) -or -not (Test-Path $isoPath)) {
        Write-Log "Office 2016: Khong tim thay ISO tai $isoPath" -Level ERROR
        Complete-Phase -State $State -CurrentPhase $phaseNum -Message "Office 2016 ISO not found"
        return
    }
    
    Write-Log "Office 2016: Dang mount ISO..." -Level INFO
    
    try {
        $mountResult = Mount-DiskImage -ImagePath $isoPath -PassThru -ErrorAction Stop
        $isoVolume = $mountResult | Get-Volume
        $driveLetter = $isoVolume.DriveLetter
        
        if (-not $driveLetter) {
            Write-Log "Office 2016: Mount thanh cong nhung khong lay duoc drive letter" -Level ERROR
            Dismount-DiskImage -ImagePath $isoPath -ErrorAction SilentlyContinue
            Complete-Phase -State $State -CurrentPhase $phaseNum -Message "Mount OK but no drive letter"
            return
        }
        
        Write-Log "Office 2016: ISO mounted tai ${driveLetter}:" -Level OK
        
        $setupExe = "${driveLetter}:\setup.exe"
        if (-not (Test-Path $setupExe)) {
            # Thu tim trong subfolder
            $setupExe = Get-ChildItem -Path "${driveLetter}:\" -Filter "setup.exe" -Recurse -Depth 2 -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($setupExe) {
                $setupExe = $setupExe.FullName
            } else {
                Write-Log "Office 2016: Khong tim thay setup.exe trong ISO" -Level ERROR
                Dismount-DiskImage -ImagePath $isoPath -ErrorAction SilentlyContinue
                Complete-Phase -State $State -CurrentPhase $phaseNum -Message "setup.exe not found in ISO"
                return
            }
        }
        
        Write-Log "Office 2016: Chay $setupExe..." -Level INFO
        $proc = Start-Process -FilePath $setupExe -PassThru
        Write-Log "Office 2016: Dang cho cai dat (co the mat 10-20 phut)..." -Level INFO
        $proc | Wait-Process -Timeout 2400 -ErrorAction SilentlyContinue
        
        if ($proc.HasExited) {
            Write-Log "Office 2016: Cai dat xong! Exit code: $($proc.ExitCode)" -Level OK
        } else {
            Write-Log "Office 2016: Qua 40 phut, bo qua cho..." -Level WARN
        }
        
        # Unmount ISO
        Start-Sleep -Seconds 5
        Dismount-DiskImage -ImagePath $isoPath -ErrorAction SilentlyContinue
        Write-Log "Office 2016: Da unmount ISO" -Level OK
        
    } catch {
        Write-Log "Office 2016: Loi - $($_.Exception.Message)" -Level ERROR
        Dismount-DiskImage -ImagePath $isoPath -ErrorAction SilentlyContinue
    }
    
} else {
    Write-Log "Office: Loai '$officeType' khong duoc ho tro" -Level ERROR
}

# ==================== HOAN TAT ====================
Complete-Phase -State $State -CurrentPhase $phaseNum -Message "Office $officeType installation attempted"
