# ================================================================
# Phase 8: Cai dat cac phan mem tuy thich (Custom Apps)
# ================================================================
param([PSCustomObject]$State, [PSCustomObject]$Config)

$phaseNum = 8
Write-Log "===== PHASE $phaseNum: CAI DAT CUSTOM APPS =====" -Level PHASE

if (-not $Config.customApps -or $Config.customApps.Length -eq 0) {
    Write-Log "Khong co phan mem tuy chon nao duoc cau hinh." -Level OK
    Complete-Phase -State $State -CurrentPhase $phaseNum -Message "No custom apps configured"
    return
}

foreach ($app in $Config.customApps) {
    $appName = if ([string]::IsNullOrEmpty($app.name)) { Split-Path $app.path -Leaf } else { $app.name }
    $appPath = $app.path
    $appArgs = $app.args

    if (-not (Test-Path $appPath)) {
        Write-Log "Custom App: Khong tim thay file '$appName' tai: $appPath" -Level WARN
        continue
    }

    Write-Log "Dang cai dat: $appName..." -Level INFO
    try {
        Unblock-File -Path $appPath -ErrorAction SilentlyContinue
        
        $procArgs = @{}
        $procArgs.FilePath = $appPath
        $procArgs.Wait = $true
        $procArgs.PassThru = $true
        
        if (-not [string]::IsNullOrEmpty($appArgs)) {
            $procArgs.ArgumentList = $appArgs
            Write-Log "Args: $appArgs" -Level INFO
        }

        $proc = Start-Process @procArgs -ErrorAction Stop
        Write-Log "Cai dat xong '$appName' - Exit Code: $($proc.ExitCode)" -Level OK
    } catch {
        Write-Log "Loi khi cai dat '$appName': $($_.Exception.Message)" -Level ERROR
    }
}

Write-Log "Hoan tat cai dat cac Custom Apps." -Level INFO

# ==================== HOAN TAT ====================
Complete-Phase -State $State -CurrentPhase $phaseNum -Message "Custom apps installed"
