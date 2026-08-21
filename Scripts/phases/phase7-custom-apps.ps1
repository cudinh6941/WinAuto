param([PSCustomObject]$State, [PSCustomObject]$Config)

. "$PSScriptRoot\..\lib\common.ps1"

Write-Log "===== BAT DAU PHASE 7: CAI DAT CUSTOM APPS =====" -Level PHASE
Send-PhaseNotification -ComputerName $State.computerName -Phase 7 -Status "start" -Message "Cai dat Custom Apps"

$dryRun = Test-DryRun
$customAppsDir = Join-Path $script:WinAutoRoot "Software\CustomApps"

if (-not (Test-Path $customAppsDir)) {
    Write-Log "Khong tim thay thu muc $customAppsDir, bo qua cai dat." -Level WARN
    Skip-Phase -State $State -CurrentPhase 7 -Reason "Khong co thu muc CustomApps"
    return
}

# Tim tat ca file .exe, .msi, .bat, .cmd
$installers = Get-ChildItem -Path $customAppsDir -Include *.exe, *.msi, *.bat, *.cmd -Recurse -File

if ($installers.Count -eq 0) {
    Write-Log "Khong co file installer nao trong $customAppsDir." -Level INFO
    Skip-Phase -State $State -CurrentPhase 7 -Reason "Khong co installer"
    return
}

Write-Log "Tim thay $($installers.Count) ung dung can cai dat." -Level INFO

foreach ($installer in $installers) {
    Write-Log "Dang cai dat: $($installer.Name)..." -Level INFO
    
    if ($dryRun) {
        Write-DryRun "SE CAI: $($installer.FullName)"
        continue
    }
    
    try {
        $ext = $installer.Extension.ToLower()
        
        if ($ext -eq ".msi") {
            $argsList = "/i `"$($installer.FullName)`" /qn /norestart"
            $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $argsList -Wait -NoNewWindow -PassThru
        } elseif ($ext -eq ".bat" -or $ext -eq ".cmd") {
            $process = Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$($installer.FullName)`"" -Wait -NoNewWindow -PassThru
        } else {
            # Xu ly rieng cho tung loai EXE dua vao ten file
            $name = $installer.Name.ToLower()
            if ($name -match "ultraviewer|unikey") {
                # Inno Setup installer
                $argsList = "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-"
            } elseif ($name -match "chrome") {
                $argsList = "/silent /install"
            } elseif ($name -match "zalo") {
                $argsList = "/VERYSILENT"
            } else {
                # Mac dinh /S cho NSIS hoac cac app khac
                $argsList = "/S" 
            }
            $process = Start-Process -FilePath $installer.FullName -ArgumentList $argsList -Wait -NoNewWindow -PassThru
        }
        
        # 3010 = ERROR_SUCCESS_REBOOT_REQUIRED
        if ($process.ExitCode -eq 0 -or $process.ExitCode -eq 3010) {
            Write-Log "Cai dat thanh cong: $($installer.Name)" -Level OK
        } else {
            Write-Log "Cai dat $($installer.Name) exit code: $($process.ExitCode)" -Level WARN
        }
    } catch {
        Write-Log "Loi khi chay file $($installer.Name): $($_.Exception.Message)" -Level ERROR
    }
}

Complete-Phase -State $State -CurrentPhase 7 -Message "Custom Apps installed ($($installers.Count) apps)"
