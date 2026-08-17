# ================================================================
# network.ps1 - Ket noi mang (WiFi / LAN)
# Tach tu setup-anydesk.ps1, dung chung cho WinAuto v2
# ================================================================

# Import common functions
$libDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $libDir "common.ps1")

function Connect-WiFi {
    param(
        [string]$SSID,
        [string]$Password
    )
    
    if ([string]::IsNullOrWhiteSpace($SSID) -or [string]::IsNullOrWhiteSpace($Password)) {
        Write-Log "WiFi: SSID hoac Password trong - bo qua" -Level WARN
        return $false
    }
    
    # Tat bang hoi Network Location
    New-Item -Path "HKLM:\System\CurrentControlSet\Control\Network\NewNetworkWindowOff" -Force -ErrorAction SilentlyContinue | Out-Null
    
    $profilesToTry = @(
        @{ Auth = "WPA2PSK"; Enc = "AES" },
        @{ Auth = "WPA3SAE"; Enc = "AES" },
        @{ Auth = "WPAPSK";  Enc = "TKIP" },
        @{ Auth = "WPA2PSK"; Enc = "TKIP" }
    )
    
    foreach ($prof in $profilesToTry) {
        $auth = $prof.Auth
        $enc = $prof.Enc
        
        $tempProfile = "$env:TEMP\TempWlanProfile_$auth.xml"
        $wlanXmlContent = @"
<?xml version="1.0"?>
<WLANProfile xmlns="http://www.microsoft.com/networking/WLAN/profile/v1">
    <name>$SSID</name>
    <SSIDConfig>
        <SSID><name>$SSID</name></SSID>
    </SSIDConfig>
    <connectionType>ESS</connectionType>
    <connectionMode>auto</connectionMode>
    <MSM>
        <security>
            <authEncryption>
                <authentication>$auth</authentication>
                <encryption>$enc</encryption>
                <useOneX>false</useOneX>
            </authEncryption>
            <sharedKey>
                <keyType>passPhrase</keyType>
                <protected>false</protected>
                <keyMaterial>$Password</keyMaterial>
            </sharedKey>
        </security>
    </MSM>
</WLANProfile>
"@
        $wlanXmlContent | Out-File -FilePath $tempProfile -Encoding UTF8 -Force
        netsh wlan add profile filename="$tempProfile" 2>$null | Out-Null
        Remove-Item $tempProfile -Force -ErrorAction SilentlyContinue
        
        Write-Log "WiFi: Thu ket noi '$SSID' chuan $auth/$enc..." -Level INFO
        netsh wlan connect name="$SSID" 2>$null | Out-Null
        Start-Sleep -Seconds 8
        
        if (Test-Internet) {
            Write-Log "WiFi: Da ket noi va co Internet!" -Level OK
            return $true
        }
        
        # Thu lan 2
        Start-Sleep -Seconds 5
        if (Test-Internet) {
            Write-Log "WiFi: Da ket noi va co Internet!" -Level OK
            return $true
        }
        
        Write-Log "WiFi: That bai voi chuan $auth, thu tiep..." -Level WARN
    }
    
    Write-Log "WiFi: KHONG KET NOI DUOC TU DONG!" -Level ERROR
    return $false
}

function Connect-Network {
    param(
        [PSCustomObject]$NetworkConfig
    )
    
    Write-Log "Mang: Kiem tra ket noi..." -Level INFO
    
    # Thu LAN truoc
    if (Test-Internet) {
        Write-Log "Mang: Da co Internet (LAN)" -Level OK
        return $true
    }
    
    # Cho LAN them 15 giay
    Write-Log "Mang: Cho LAN ket noi (15s)..." -Level INFO
    Start-Sleep -Seconds 15
    if (Test-Internet) {
        Write-Log "Mang: Da co Internet (LAN)" -Level OK
        return $true
    }
    
    # Thu WiFi neu config cho phep
    if ($NetworkConfig -and $NetworkConfig.wifi -and $NetworkConfig.wifi.enabled) {
        Write-Log "Mang: LAN khong co, thu WiFi..." -Level INFO
        $result = Connect-WiFi -SSID $NetworkConfig.wifi.ssid -Password $NetworkConfig.wifi.password
        if ($result) { return $true }
    }
    
    # Cho them 30 giay lan cuoi
    Write-Log "Mang: Cho them 30s..." -Level WARN
    Start-Sleep -Seconds 30
    if (Test-Internet) {
        Write-Log "Mang: Da co Internet!" -Level OK
        return $true
    }
    
    Write-Log "Mang: VAN KHONG CO INTERNET" -Level ERROR
    return $false
}
