# ==================== HAM KIEM TRA INTERNET ====================
function Test-Internet {
    try {
        $result = Test-Connection -ComputerName "8.8.8.8" -Count 1 -Quiet -ErrorAction SilentlyContinue
        return $result
    } catch {
        return $false
    }
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "   TEST CÀI DRIVER MẠNG & KẾT NỐI WIFI" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# ==================== BUOC 1: CAI DRIVER MANG (3DP NET) ====================
$wifiAdapters = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "Wi-Fi|Wireless|WLAN" -or $_.InterfaceDescription -match "Wi-Fi|Wireless|WLAN|802\.11" }

if (-not $wifiAdapters) {
    $driverInstaller = "$PSScriptRoot\3dpnet.exe"
    if (Test-Path $driverInstaller) {
        Write-Host "Không tìm thấy driver WiFi! Đang cài 3DP Net tự động (không hỏi path)..." -ForegroundColor Yellow
        try {
            # 3DP Net thường đóng gói dạng 7-zip SFX. Tham số -y (yes), -gm2 (ẩn UI), -o (set path)
            $proc = Start-Process -FilePath $driverInstaller -ArgumentList "-y", "-gm2", "-o`"C:\3DPNet`"" -PassThru
            Write-Host "3DP Net: Đang chờ giải nén..."
            
            $proc | Wait-Process -Timeout 60 -ErrorAction SilentlyContinue
            
            if (-not $proc.HasExited) {
                Write-Host "3DP Net: Giải nén hơi lâu, bỏ qua chờ để tiếp tục..." -ForegroundColor Yellow
            } else {
                Write-Host "3DP Net: Giải nén xong! Nếu có bảng 3DP Net hiện lên, bạn có thể click cài." -ForegroundColor Green
            }
            Write-Host "3DP Net: Đợi driver load (15s)..."
            Start-Sleep -Seconds 15
        } catch {
            Write-Host "3DP Net: Lỗi cài đặt - $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "3DP Net: Không tìm thấy file 3dpnet.exe tại $PSScriptRoot - bỏ qua" -ForegroundColor Yellow
    }
} else {
    Write-Host "Đã có sẵn Driver WiFi -> BỎ QUA cài 3DP Net để tiết kiệm thời gian!" -ForegroundColor Green
}

# ==================== BUOC 2: KET NOI WI-FI ====================
Write-Host ""
Write-Host "--- Nhập thông tin WiFi để test kết nối ---" -ForegroundColor Yellow
$wifiName = Read-Host "Nhập tên WiFi (SSID)"
$wifiPass = Read-Host "Nhập mật khẩu WiFi"

if (-not [string]::IsNullOrWhiteSpace($wifiName) -and -not [string]::IsNullOrWhiteSpace($wifiPass)) {
    # Tắt bảng hỏi Network Location (Discoverable)
    New-Item -Path "HKLM:\System\CurrentControlSet\Control\Network\NewNetworkWindowOff" -Force -ErrorAction SilentlyContinue | Out-Null

    $profilesToTry = @(
        @{ Auth="WPA2PSK"; Enc="AES" },
        @{ Auth="WPA3SAE"; Enc="AES" },
        @{ Auth="WPAPSK"; Enc="TKIP" },
        @{ Auth="WPA2PSK"; Enc="TKIP" }
    )

    $wifiConnected = $false
    foreach ($prof in $profilesToTry) {
        if ($wifiConnected) { break }
        
        $auth = $prof.Auth
        $enc = $prof.Enc
        
        $tempProfile = "$env:TEMP\TempWlanProfile_$auth.xml"
        $wlanXmlContent = @"
<?xml version="1.0"?>
<WLANProfile xmlns="http://www.microsoft.com/networking/WLAN/profile/v1">
    <name>$wifiName</name>
    <SSIDConfig>
        <SSID><name>$wifiName</name></SSID>
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
                <keyMaterial>$wifiPass</keyMaterial>
            </sharedKey>
        </security>
    </MSM>
</WLANProfile>
"@
        $wlanXmlContent | Out-File -FilePath $tempProfile -Encoding UTF8 -Force

        netsh wlan add profile filename="$tempProfile" | Out-Null
        Remove-Item $tempProfile -Force -ErrorAction SilentlyContinue

        Write-Host "WiFi: Thử kết nối '$wifiName' chuẩn $auth/$enc..."
        netsh wlan connect name="$wifiName" | Out-Null
        Start-Sleep -Seconds 8

        if (Test-Internet) {
            Write-Host "WiFi: Đã kết nối và có Internet với chuẩn $auth!" -ForegroundColor Green
            $wifiConnected = $true
        } else {
            Start-Sleep -Seconds 5
            if (Test-Internet) {
                Write-Host "WiFi: Đã kết nối và có Internet với chuẩn $auth!" -ForegroundColor Green
                $wifiConnected = $true
            } else {
                Write-Host "WiFi: Thất bại với chuẩn $auth, thử chuẩn khác..." -ForegroundColor Yellow
            }
        }
    }

    if (-not $wifiConnected) {
        Write-Host "WiFi: KHÔNG KẾT NỐI ĐƯỢC TỰ ĐỘNG! (Kiểm tra lại mật khẩu hoặc thử kết nối bằng tay)" -ForegroundColor Red
    }
} else {
    Write-Host "WiFi: Tên hoặc mật khẩu bị trống - bỏ qua kết nối" -ForegroundColor Yellow
}

# ==================== KẾT QUẢ ====================
Write-Host "==========================================" -ForegroundColor Cyan
if (Test-Internet) {
    Write-Host "KẾT QUẢ: MẠNG ĐÃ KẾT NỐI THÀNH CÔNG!" -ForegroundColor Green
} else {
    Write-Host "KẾT QUẢ: VẪN CHƯA CÓ INTERNET (Check lai driver hoac mat khau wifi)!" -ForegroundColor Red
}
Write-Host "==========================================" -ForegroundColor Cyan

Read-Host "Nhan Enter de thoat"
