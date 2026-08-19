param([PSCustomObject]$State, [PSCustomObject]$Config)

. "$PSScriptRoot\..\lib\common.ps1"
Write-Log "===== BAT DAU PHASE 8: CAI DAT CUSTOM APPS =====" -Level PHASE

$customAppsDir = Join-Path $script:WinAutoRoot "Software\CustomApps"

if (Test-Path $customAppsDir) {
    # Tim tat ca file .exe, .msi, .bat, .cmd
    $installers = Get-ChildItem -Path $customAppsDir -Include *.exe, *.msi, *.bat, *.cmd -Recurse -File
    
    if ($installers.Count -gt 0) {
        Write-Log "Tim thay $($installers.Count) ung dung can cai dat trong CustomApps." -Level INFO
        
        foreach ($installer in $installers) {
            Write-Log "Dang cai dat: $($installer.Name)..." -Level INFO
            
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
                    if ($name -match "ultraviewer") {
                        # Inno Setup installer
                        $argsList = "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-"
                    } elseif ($name -match "unikey") {
                        # Unikey thuong la phan mem portable hoac dung Inno
                        $argsList = "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-"
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
                    Write-Log "Cai dat $($installer.Name) hoan tat voi Exit Code: $($process.ExitCode)" -Level WARN
                }
            } catch {
                Write-Log "Loi khi chay file $($installer.Name): $($_.Exception.Message)" -Level ERROR
            }
        }
    } else {
        Write-Log "Khong co file .exe/.msi/.bat/.cmd nao trong $customAppsDir." -Level INFO
    }
} else {
    Write-Log "Khong tim thay thu muc $customAppsDir, bo qua cai dat." -Level WARN
}

Complete-Phase -State $State -CurrentPhase 8 -Message "Custom Apps installed"
