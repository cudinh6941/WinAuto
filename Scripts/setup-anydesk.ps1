# ==================== CAU HINH ====================
$token    = "8868470986:AAEOtgjpH56MoOhpywSfbAceKLCIKdFNgj0"
$chatId   = "1184601478"
$password = "Cds@1124"
# ===================================================

# ==================== HAM GHI LOG ====================
$logFile = "C:\WinAuto_setup.log"
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$timestamp] $Message"
    Add-Content -Path $logFile -Value $entry -Force
    Write-Host $entry
}

# ==================== HAM GUI TELEGRAM (CO RETRY) ====================
function Send-Telegram {
    param([string]$Message)
    $url = "https://api.telegram.org/bot$token/sendMessage"
    $body = @{ chat_id = $chatId; text = $Message; parse_mode = "HTML" } | ConvertTo-Json -Compress

    for ($i = 1; $i -le 3; $i++) {
        try {
            $null = Invoke-RestMethod -Uri $url -Method Post -Body $body -ContentType "application/json; charset=utf-8" -TimeoutSec 30
            Write-Log "Telegram: Gui thanh cong (lan $i)"
            return $true
        } catch {
            Write-Log "Telegram: Lan $i that bai - $($_.Exception.Message)"
            if ($i -lt 3) { Start-Sleep -Seconds 10 }
        }
    }
    Write-Log "Telegram: DA THU 3 LAN - KHONG GUI DUOC"
    return $false
}

# ==================== HAM KIEM TRA INTERNET ====================
function Test-Internet {
    try {
        $result = Test-Connection -ComputerName "8.8.8.8" -Count 1 -Quiet -ErrorAction SilentlyContinue
        return $result
    } catch {
        return $false
    }
}

Write-Log "=========================================="
Write-Log "BAT DAU SETUP WINAUTO"
Write-Log "Computer: $env:COMPUTERNAME"
Write-Log "=========================================="

# ==================== BUOC 0: CHO HE THONG ON DINH ====================
Write-Log "Cho 15 giay cho he thong on dinh..."
Start-Sleep -Seconds 15

# ==================== BUOC 1: CAI DRIVER MANG (3DP NET) ====================
$driverInstaller = "C:\Windows\Setup\Scripts\3dpnet.exe"
if (Test-Path $driverInstaller) {
    Write-Log "Dang cai driver mang 3DP Net..."
    try {
        # Chay 3DP Net - dat timeout 120 giay
        # Neu no hien GUI (khong silent duoc) thi tu kill sau 120s
        $proc = Start-Process -FilePath $driverInstaller -ArgumentList "/S", "/D=C:\3DPNet" -PassThru
        $timeout = 120
        $waited = 0
        while (-not $proc.HasExited -and $waited -lt $timeout) {
            Start-Sleep -Seconds 5
            $waited += 5
            Write-Log "3DP Net: Dang cho... ($waited/$timeout giay)"
        }
        if (-not $proc.HasExited) {
            Write-Log "3DP Net: Qua timeout ${timeout}s - co the dang hien GUI. Kill va tiep tuc..."
            $proc | Stop-Process -Force -ErrorAction SilentlyContinue
        } else {
            Write-Log "3DP Net: Cai xong!"
        }
        Write-Log "3DP Net: Cho driver load..."
        Start-Sleep -Seconds 20
    } catch {
        Write-Log "3DP Net: Loi cai dat - $($_.Exception.Message)"
    }
} else {
    Write-Log "3DP Net: Khong tim thay file tai $driverInstaller - bo qua"
}


# ==================== BUOC 2: KET NOI WI-FI ====================
$wlanProfile = "C:\Windows\Setup\Scripts\WlanProfile.xml"

if (Test-Path $wlanProfile) {
    try {
        [xml]$wlanXml = Get-Content $wlanProfile -Encoding UTF8
        $wifiName = $wlanXml.WLANProfile.name
        Write-Log "WiFi: Doc duoc ten tu profile: '$wifiName'"
    } catch {
        Write-Log "WiFi: Khong doc duoc ten tu XML - $($_.Exception.Message)"
        $wifiName = $null
    }

    if ($wifiName) {
        Write-Log "WiFi: Them profile..."
        netsh wlan add profile filename="$wlanProfile" | Out-Null

        $wifiConnected = $false
        for ($i = 1; $i -le 5; $i++) {
            Write-Log "WiFi: Thu ket noi '$wifiName' (lan $i/5)..."
            netsh wlan connect name="$wifiName" | Out-Null
            Start-Sleep -Seconds 10

            if (Test-Internet) {
                Write-Log "WiFi: Da ket noi va co Internet!"
                $wifiConnected = $true
                break
            } else {
                Write-Log "WiFi: Chua co Internet, thu lai..."
                if ($i -lt 5) { Start-Sleep -Seconds 5 }
            }
        }

        if (-not $wifiConnected) {
            Write-Log "WiFi: KHONG KET NOI DUOC SAU 5 LAN THU"
        }
    }
} else {
    Write-Log "WiFi: Khong tim thay WlanProfile.xml - bo qua"
}

# Kiem tra lai Internet (co the da co qua Ethernet)
if (-not (Test-Internet)) {
    Write-Log "Mang: Cho them 30 giay cho ket noi Ethernet..."
    Start-Sleep -Seconds 30
    if (Test-Internet) {
        Write-Log "Mang: Da co Internet qua Ethernet!"
    } else {
        Write-Log "Mang: VAN KHONG CO INTERNET - Tiep tuc cai AnyDesk offline"
    }
}

# ==================== BUOC 3: CAI DAT ANYDESK ====================
$installedPath  = "C:\Program Files (x86)\AnyDesk\AnyDesk.exe"
$localInstaller = "C:\Windows\Setup\Scripts\AnyDesk.exe"

if (-not (Test-Path $installedPath)) {
    if (Test-Path $localInstaller) {
        Write-Log "AnyDesk: Dang cai dat tu installer offline..."
        try {
            Start-Process -FilePath $localInstaller -ArgumentList "--install", '"C:\Program Files (x86)\AnyDesk"', "--silent", "--start-with-win" -Wait
            Write-Log "AnyDesk: Cai dat xong!"
            Start-Sleep -Seconds 5
        } catch {
            Write-Log "AnyDesk: Loi cai dat - $($_.Exception.Message)"
        }
    } else {
        Write-Log "AnyDesk: KHONG TIM THAY INSTALLER tai $localInstaller"
    }
} else {
    Write-Log "AnyDesk: Da duoc cai san"
}

# ==================== BUOC 4: CAU HINH ANYDESK ====================
if (Test-Path $installedPath) {
    $configDir = "$env:ProgramData\AnyDesk"
    $configFile = "$configDir\system.conf"

    # 4a. Cho AnyDesk khoi dong va tao config file
    Write-Log "AnyDesk: Khoi dong lan dau de tao config..."
    Start-Process -FilePath $installedPath
    Start-Sleep -Seconds 10

    # Cho config file duoc tao
    $configWait = 0
    while ((-not (Test-Path $configFile)) -and ($configWait -lt 60)) {
        Start-Sleep -Seconds 3
        $configWait += 3
        Write-Log "AnyDesk: Cho config file... ($configWait/60s)"
    }

    # 4b. Dung AnyDesk de sua config
    Write-Log "AnyDesk: Dung AnyDesk de sua config..."
    Stop-Process -Name "AnyDesk" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3

    # Dung service AnyDesk neu co
    Stop-Service -Name "AnyDesk" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2

    if (Test-Path $configFile) {
        Write-Log "AnyDesk: Dang ghi cau hinh unattended access..."
        try {
            $config = Get-Content $configFile -Raw

            # Cac setting can thiet de cho phep remote login
            $settingsToAdd = @(
                "ad.security.interactive_access=0",
                "ad.security.allow_remote_control=true",
                "ad.security.allow_remote_restart=true",
                "ad.security.allow_remote_clipboard=true",
                "ad.security.allow_remote_file_manager=true"
            )

            foreach ($setting in $settingsToAdd) {
                $settingName = $setting.Split("=")[0]
                if ($config -match [regex]::Escape($settingName)) {
                    # Setting da co -> thay the gia tri
                    $config = $config -replace "$settingName=.*", $setting
                } else {
                    # Setting chua co -> them vao cuoi
                    $config = $config + "`n$setting"
                }
            }

            # Ghi lai file config
            $config | Set-Content -Path $configFile -Force
            Write-Log "AnyDesk: Da ghi 5 setting vao config"
        } catch {
            Write-Log "AnyDesk: Loi ghi config - $($_.Exception.Message)"
        }
    } else {
        Write-Log "AnyDesk: KHONG TIM THAY config file sau 60s"
    }

    # 4c. Khoi dong lai AnyDesk service
    Write-Log "AnyDesk: Khoi dong lai service..."
    Start-Service -Name "AnyDesk" -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 5

    # Dat password bang cach tao file .cmd tam thoi (Dam bao dung cu phap 100%)
    Write-Log "AnyDesk: Dat mat khau '$password'..."
    $batPath = "$env:TEMP\set_anydesk_pass.cmd"
    $batContent = "echo $password| `"$installedPath`" --set-password"
    $batContent | Out-File -FilePath $batPath -Encoding ASCII
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$batPath`"" -Wait -WindowStyle Hidden
    Start-Sleep -Seconds 3
    Remove-Item -Path $batPath -Force -ErrorAction SilentlyContinue
    Write-Log "AnyDesk: Da dat mat khau qua CMD"

    # Bat GUI len sau cung
    Write-Log "AnyDesk: Bat giao dien..."
    Start-Process -FilePath $installedPath
    Start-Sleep -Seconds 5

    # 4c. Lay AnyDesk ID
    Write-Log "AnyDesk: Dang lay ID..."
    $idFile = "$env:TEMP\anydesk_id.txt"
    try {
        Start-Process -FilePath $installedPath -ArgumentList "--get-id" -NoNewWindow -Wait -RedirectStandardOutput $idFile
        Start-Sleep -Seconds 5

        $anydeskId = ""
        if (Test-Path $idFile) {
            $anydeskId = (Get-Content $idFile -Raw).Trim()
            $anydeskId = $anydeskId -replace "\s+", ""
            Remove-Item $idFile -Force -ErrorAction SilentlyContinue
        }
        Write-Log "AnyDesk: ID = '$anydeskId'"
    } catch {
        Write-Log "AnyDesk: Loi lay ID - $($_.Exception.Message)"
        $anydeskId = ""
    }
} else {
    Write-Log "AnyDesk: KHONG CAI DUOC - bo qua config"
    $anydeskId = ""
}

# ==================== BUOC 5: GUI TELEGRAM ====================
$computerName = $env:COMPUTERNAME
$currentTime = Get-Date -Format "dd/MM/yyyy HH:mm"

if (-not [string]::IsNullOrEmpty($anydeskId)) {
    $message = "<b>May tinh da cai xong!</b>`n" +
               "Ten may: $computerName`n" +
               "AnyDesk ID: <code>$anydeskId</code>`n" +
               "Password: <code>$password</code>`n" +
               "Thoi gian: $currentTime"
    Write-Log "Gui Telegram voi AnyDesk ID..."
} else {
    $message = "<b>May tinh da cai xong!</b>`n" +
               "Ten may: $computerName`n" +
               "Khong lay duoc AnyDesk ID`n" +
               "Thoi gian: $currentTime"
    Write-Log "Gui Telegram KHONG CO AnyDesk ID (fallback)..."
}

if (Test-Internet) {
    Send-Telegram -Message $message
} else {
    Write-Log "KHONG CO INTERNET - khong gui duoc Telegram"
}

# ==================== BUOC 6: COPY SHORTCUT RA DESKTOP ====================
$shortcutSource = "C:\Windows\Setup\Scripts\AnyDesk.lnk"
$desktopPath = [System.Environment]::GetFolderPath("Desktop")
$publicDesktop = "$env:PUBLIC\Desktop"

if (Test-Path $shortcutSource) {
    Copy-Item $shortcutSource "$desktopPath\AnyDesk.lnk" -Force -ErrorAction SilentlyContinue
    Copy-Item $shortcutSource "$publicDesktop\AnyDesk.lnk" -Force -ErrorAction SilentlyContinue
    Write-Log "AnyDesk shortcut da copy ra Desktop"
}

Write-Log "=========================================="
Write-Log "HOAN TAT SETUP WINAUTO"
Write-Log "=========================================="