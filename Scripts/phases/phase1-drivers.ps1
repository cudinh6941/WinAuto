# ================================================================
# Phase 1: Cai driver mang + Ket noi internet
# ================================================================
param([PSCustomObject]$State, [PSCustomObject]$Config)

$phaseNum = 1
Write-Log "===== PHASE $phaseNum: CAI DRIVER MANG + KET NOI INTERNET =====" -Level PHASE

# ==================== CAI DRIVER MANG (3DP NET) ====================
$wifiAdapters = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object {
    $_.Name -match "Wi-Fi|Wireless|WLAN" -or 
    $_.InterfaceDescription -match "Wi-Fi|Wireless|WLAN|802\.11"
}

if (-not $wifiAdapters) {
    $driverInstaller = Join-Path $script:WinAutoRoot "Scripts\3dpnet.exe"
    if (Test-Path $driverInstaller) {
        Write-Log "Khong thay driver WiFi, dang cai 3DP Net..." -Level INFO
        try {
            Unblock-File -Path $driverInstaller -ErrorAction SilentlyContinue
            $proc = Start-Process -FilePath $driverInstaller -ArgumentList "-y", "-gm2", "-o`"C:\3DPNet`"" -PassThru
            Write-Log "3DP Net: Dang cho giai nen..." -Level INFO
            $proc | Wait-Process -Timeout 120 -ErrorAction SilentlyContinue
            
            if (-not $proc.HasExited) {
                Write-Log "3DP Net: Giai nen qua 120s, bo qua cho..." -Level WARN
            } else {
                Write-Log "3DP Net: Giai nen xong!" -Level OK
            }
            
            Write-Log "3DP Net: Doi driver load (20s)..." -Level INFO
            Start-Sleep -Seconds 20
        } catch {
            Write-Log "3DP Net: Loi cai dat - $($_.Exception.Message)" -Level ERROR
        }
    } else {
        Write-Log "3DP Net: Khong tim thay file tai $driverInstaller" -Level WARN
    }
} else {
    Write-Log "Da co san driver WiFi, bo qua cai 3DP Net" -Level OK
}

# ==================== KET NOI MANG ====================
$networkConnected = Connect-Network -NetworkConfig $Config.network

if (-not $networkConnected) {
    Write-Log "CANH BAO: Khong co internet. Mot so buoc sau co the that bai." -Level ERROR
}

# ==================== HOAN TAT ====================
Complete-Phase -State $State -CurrentPhase $phaseNum -Message "Driver + Network done. Internet: $networkConnected"
