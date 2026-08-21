param([PSCustomObject]$State, [PSCustomObject]$Config)

. "$PSScriptRoot\..\lib\common.ps1"

Write-Log "===== BAT DAU PHASE 6: CAI OFFICE =====" -Level PHASE
Send-PhaseNotification -ComputerName $State.computerName -Phase 6 -Status "start" -Message "Cai Office $($State.officeType)"

$dryRun = Test-DryRun
$officeType = $State.officeType

Write-Log "Office type: $officeType" -Level INFO

# ==================== CAI OFFICE 365 ====================
if ($officeType -eq "365") {
    $installerPath = $Config.office.'365'.installerPath
    Write-Log "Office 365 installer: $installerPath" -Level INFO
    
    if (-not (Test-Path $installerPath)) {
        Write-Log "KHONG TIM THAY: $installerPath" -Level ERROR
        Send-PhaseNotification -ComputerName $State.computerName -Phase 6 -Status "error" -Message "Thieu file Office 365 installer"
        Complete-Phase -State $State -CurrentPhase 6 -Message "Office 365 - thieu installer"
        return
    }
    
    if ($dryRun) {
        Write-DryRun "SE CHAY: $installerPath /configure"
        Complete-Phase -State $State -CurrentPhase 6 -Message "[DRY-RUN] Office 365"
        return
    }
    
    Write-Log "Dang cai Office 365 (co the mat 10-20 phut)..." -Level INFO
    try {
        # Office Deployment Tool - setup.exe /configure configuration.xml
        $officeDir = Split-Path $installerPath -Parent
        $configXml = Get-ChildItem -Path $officeDir -Filter "*.xml" -File | Select-Object -First 1
        
        if ($configXml) {
            $proc = Start-Process -FilePath $installerPath -ArgumentList "/configure `"$($configXml.FullName)`"" -Wait -NoNewWindow -PassThru
        } else {
            # Chay truc tiep neu khong co XML
            $proc = Start-Process -FilePath $installerPath -Wait -NoNewWindow -PassThru
        }
        
        Write-Log "Office 365 installer exit code: $($proc.ExitCode)" -Level INFO
        
        if ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq 3010) {
            Write-Log "Cai Office 365 thanh cong!" -Level OK
        } else {
            Write-Log "Office 365 exit voi code: $($proc.ExitCode)" -Level WARN
        }
    } catch {
        Write-Log "Loi cai Office 365: $($_.Exception.Message)" -Level ERROR
    }
}

# ==================== CAI OFFICE 2016 ====================
elseif ($officeType -eq "2016") {
    $isoPath = $Config.office.'2016'.isoPath
    Write-Log "Office 2016 ISO: $isoPath" -Level INFO
    
    if (-not (Test-Path $isoPath)) {
        Write-Log "KHONG TIM THAY: $isoPath" -Level ERROR
        Send-PhaseNotification -ComputerName $State.computerName -Phase 6 -Status "error" -Message "Thieu file Office 2016 ISO"
        Complete-Phase -State $State -CurrentPhase 6 -Message "Office 2016 - thieu ISO"
        return
    }
    
    if ($dryRun) {
        Write-DryRun "SE MOUNT: $isoPath"
        Write-DryRun "SE CHAY: setup.exe /adminfile hoac setup.exe"
        Complete-Phase -State $State -CurrentPhase 6 -Message "[DRY-RUN] Office 2016"
        return
    }
    
    Write-Log "Mount ISO Office 2016..." -Level INFO
    try {
        $mountResult = Mount-DiskImage -ImagePath $isoPath -PassThru -ErrorAction Stop
        $volume = $mountResult | Get-Volume
        $isoDrive = "$($volume.DriveLetter):"
        Write-Log "ISO mounted tai $isoDrive" -Level OK
        
        # Tim setup.exe
        $setupExe = Join-Path $isoDrive "setup.exe"
        if (-not (Test-Path $setupExe)) {
            $setupExe = Get-ChildItem -Path $isoDrive -Filter "setup.exe" -Recurse -File | Select-Object -First 1
            if ($setupExe) { $setupExe = $setupExe.FullName }
        }
        
        if ($setupExe -and (Test-Path $setupExe)) {
            Write-Log "Dang cai Office 2016 (co the mat 10-20 phut)..." -Level INFO
            $proc = Start-Process -FilePath $setupExe -Wait -NoNewWindow -PassThru
            Write-Log "Office 2016 exit code: $($proc.ExitCode)" -Level INFO
        } else {
            Write-Log "Khong tim thay setup.exe trong ISO!" -Level ERROR
        }
        
        # Unmount ISO
        Dismount-DiskImage -ImagePath $isoPath -ErrorAction SilentlyContinue | Out-Null
        Write-Log "Da unmount ISO" -Level OK
        
    } catch {
        Write-Log "Loi cai Office 2016: $($_.Exception.Message)" -Level ERROR
        Dismount-DiskImage -ImagePath $isoPath -ErrorAction SilentlyContinue | Out-Null
    }
}

else {
    Write-Log "Office type khong hop le: $officeType" -Level WARN
    Skip-Phase -State $State -CurrentPhase 6 -Reason "Office type khong hop le: $officeType"
    return
}

Complete-Phase -State $State -CurrentPhase 6 -Message "Office $officeType da cai"
