param([PSCustomObject]$State, [PSCustomObject]$Config)

. "$PSScriptRoot\..\lib\common.ps1"
. "$PSScriptRoot\..\lib\network.ps1"

Write-Log "===== BAT DAU PHASE 1: CAI DRIVER MANG + KET NOI =====" -Level PHASE
Send-PhaseNotification -ComputerName $State.computerName -Phase 1 -Status "start" -Message "Cai driver mang va ket noi"

$dryRun = Test-DryRun

# ==================== CAI DRIVER MANG ====================
$driverExe = Join-Path $PSScriptRoot "..\3dpnet.exe"

if (Test-Path $driverExe) {
    if ($dryRun) {
        Write-DryRun "SE CHAY: $driverExe /S (cai driver mang offline)"
    } else {
        Write-Log "Dang cai driver mang tu 3dpnet.exe..." -Level INFO
        try {
            $proc = Start-Process -FilePath $driverExe -ArgumentList "/S" -Wait -NoNewWindow -PassThru
            if ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq 3010) {
                Write-Log "Cai driver mang thanh cong (Exit: $($proc.ExitCode))" -Level OK
            } else {
                Write-Log "3dpnet.exe exit code: $($proc.ExitCode)" -Level WARN
            }
        } catch {
            Write-Log "Loi khi cai driver mang: $($_.Exception.Message)" -Level ERROR
        }
    }
} else {
    Write-Log "Khong tim thay 3dpnet.exe - co the da co driver san" -Level INFO
}

# ==================== KET NOI MANG ====================
Write-Log "Ket noi mang (LAN/WiFi)..." -Level INFO

# Cho driver load xong
Start-Sleep -Seconds 5

$networkConnected = Connect-Network -NetworkConfig $Config.network

if ($networkConnected) {
    Write-Log "Da co ket noi Internet!" -Level OK
} else {
    Write-Log "KHONG CO INTERNET - Cac phase sau co the anh huong!" -Level ERROR
    # Van tiep tuc - mot so phase khong can internet
}

Complete-Phase -State $State -CurrentPhase 1 -Message "Driver mang + ket noi hoan tat"
