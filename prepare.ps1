# ================================================================
# prepare.ps1 - Script chuan bi cai lai Windows tu xa (AN TOAN)
# Chay script nay tren may can cai lai. No se tu dong:
#   1. Hoi ban cai Win 10 hay Win 11
#   2. Phat hien partition C: (DiskID, PartitionID)
#   3. Giai nen ISO, tao $OEM$, copy scripts
#   4. Sinh autounattend.xml dung cho may
#   5. Chay setup.exe -> may tu cai lai
# ================================================================

param(
    [string]$IsoPath
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$setupFolder = "C:\WinSetup"

# ==================== HAM TIEN ICH ====================
function Write-Banner {
    Write-Host ""
    Write-Host "  =====================================================" -ForegroundColor Cyan
    Write-Host "  |        WinAuto - Cai lai Windows tu xa            |" -ForegroundColor Cyan
    Write-Host "  |     Developed by Pham Kha Dinh - PTSC Quang Ngai  |" -ForegroundColor Cyan
    Write-Host "  =====================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Step {
    param([int]$Num, [string]$Text)
    Write-Host "  [$Num] " -NoNewline -ForegroundColor Yellow
    Write-Host $Text
}

function Write-Ok {
    param([string]$Text)
    Write-Host "  [OK] " -NoNewline -ForegroundColor Green
    Write-Host $Text
}

function Write-Warn {
    param([string]$Text)
    Write-Host "  [!!] " -NoNewline -ForegroundColor Red
    Write-Host $Text
}

function Test-Admin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# ==================== KIEM TRA QUYEN ADMIN ====================
Write-Banner

if (-not (Test-Admin)) {
    Write-Warn "Script can chay voi quyen ADMINISTRATOR!"
    Write-Warn "Click chuot phai PowerShell -> Run as Administrator"
    Write-Host ""
    Read-Host "Nhan Enter de thoat"
    exit 1
}
Write-Ok "Dang chay voi quyen Administrator"

# ==================== BUOC 0: KIEM TRA AN TOAN (PRE-CHECK) ====================
Write-Host ""
Write-Step 0 "Kiem tra an toan he thong..."

$sysDrive = $env:SystemDrive.Substring(0,1)
$cDrive = Get-Volume -DriveLetter $sysDrive -ErrorAction SilentlyContinue
if ($cDrive) {
    $freeSpaceGB = [math]::Round($cDrive.SizeRemaining / 1GB, 2)
    if ($freeSpaceGB -lt 25) {
        Write-Host ""
        Write-Host "  [X] CANH BAO DO: O dia chua he dieu hanh hien tai (${sysDrive}:) chi con $freeSpaceGB GB trong!" -ForegroundColor Red
        Write-Host "      Vui long don dep de trong it nhat 25GB roi moi chay luong Auto." -ForegroundColor Red
        Write-Host ""
        Read-Host "  Nhan Enter de thoat..."
        exit 1
    } else {
        Write-Ok "Dung luong trong o ${sysDrive}: ok ($freeSpaceGB GB)"
    }
}

$physicalDisks = Get-Disk | Where-Object {$_.BusType -ne "USB" -and $_.BusType -ne "File Backed Virtual"}
if ($physicalDisks.Count -gt 1) {
    Write-Host ""
    Write-Host "  [!] CANH BAO VANG: May dang co $($physicalDisks.Count) o cung vat ly." -ForegroundColor Yellow
    Write-Host "      Script da gài Bùa Dinh Vi (Marker Failsafe) de bao ve tuyet doi o Data." -ForegroundColor Yellow
    Write-Host ""
} else {
    Write-Ok "So luong o cung: 1 (An toan tuyet doi)"
}

# ==================== BUOC 1: CHON PHIEN BAN WINDOWS ====================
Write-Host ""
Write-Step 1 "Chon phien ban Windows can cai:"
Write-Host "      [1] Windows 10 Home" -ForegroundColor White
Write-Host "      [2] Windows 11 Home (co bypass TPM/SecureBoot)" -ForegroundColor White
Write-Host ""

do {
    $winChoice = Read-Host "  Nhap 1 hoac 2"
} while ($winChoice -ne "1" -and $winChoice -ne "2")

if ($winChoice -eq "1") {
    $winVersion = "Windows 10 Home"
    $templateFile = Join-Path $scriptDir "autounattend_win10.xml"
} else {
    $winVersion = "Windows 11 Home"
    $templateFile = Join-Path $scriptDir "autounattend_win11.xml"
}
Write-Ok "Da chon: $winVersion"

# ==================== BUOC 2: CAU HINH WIFI ====================
Write-Host ""
Write-Step 2 "Cau hinh ket noi mang sau khi cai xong:"
Write-Host "      [1] Dung WiFi - nhap ten va mat khau WiFi" -ForegroundColor White
Write-Host "      [2] Dung day LAN - bo qua WiFi" -ForegroundColor White
Write-Host ""

do {
    $netChoice = Read-Host "  Nhap 1 hoac 2"
} while ($netChoice -ne "1" -and $netChoice -ne "2")

$scriptsDir = Join-Path $scriptDir "Scripts"

if ($netChoice -eq "1") {
    $wifiName = Read-Host "  Nhap ten WiFi (SSID)"
    $wifiPass = Read-Host "  Nhap mat khau WiFi"

    if ([string]::IsNullOrEmpty($wifiName) -or [string]::IsNullOrEmpty($wifiPass)) {
        Write-Warn "Ten WiFi va mat khau khong duoc de trong!"
        Read-Host "Nhan Enter de thoat"
        exit 1
    }

    # Luu thong tin WiFi vao file text de setup-anydesk.ps1 tu dong thu nhieu chuan bao mat khac nhau
    $wifiCredPath = Join-Path $scriptsDir "wifi_credentials.txt"
    "$wifiName`n$wifiPass" | Out-File -FilePath $wifiCredPath -Encoding UTF8 -Force
    Write-Ok "Da tao wifi_credentials.txt cho mạng: '$wifiName'"
} else {
    Write-Ok "Bo qua WiFi - se dung day LAN"
}

# ==================== BUOC 3: TIM FILE ISO ====================
Write-Step 3 "Tim file ISO Windows..."

if ([string]::IsNullOrEmpty($IsoPath)) {
    Write-Host "      Dang quet tim file .iso tren may..." -ForegroundColor Gray
    $isoFiles = @()
    $searchPaths = @("C:\", "D:\", "E:\", "$env:USERPROFILE\Downloads", "$env:USERPROFILE\Desktop")
    
    foreach ($searchPath in $searchPaths) {
        if (Test-Path $searchPath) {
            $found = Get-ChildItem -Path $searchPath -Filter "*.iso" -File -ErrorAction SilentlyContinue -Depth 1
            if ($found) { $isoFiles += $found }
        }
    }

    if ($isoFiles.Count -gt 0) {
        Write-Host ""
        Write-Host "      Tim thay cac file ISO:" -ForegroundColor White
        for ($i = 0; $i -lt $isoFiles.Count; $i++) {
            $sizeGB = [math]::Round($isoFiles[$i].Length / 1GB, 2)
            $idx = $i + 1
            $fName = $isoFiles[$i].FullName
            Write-Host "      [$idx] $fName ($sizeGB GB)" -ForegroundColor White
        }
        Write-Host "      [0] Nhap duong dan thu cong" -ForegroundColor Gray
        Write-Host ""

        do {
            $isoChoice = Read-Host "  Chon so"
        } while ([int]$isoChoice -lt 0 -or [int]$isoChoice -gt $isoFiles.Count)

        if ($isoChoice -eq "0") {
            $IsoPath = Read-Host "  Nhap duong dan ISO"
        } else {
            $IsoPath = $isoFiles[[int]$isoChoice - 1].FullName
        }
    } else {
        $IsoPath = Read-Host "  Khong tim thay ISO. Nhap duong dan thu cong"
    }
}

if (-not (Test-Path $IsoPath)) {
    Write-Warn "Khong tim thay file: $IsoPath"
    Read-Host "Nhan Enter de thoat"
    exit 1
}
$isoSize = [math]::Round((Get-Item $IsoPath).Length / 1GB, 2)
Write-Ok "ISO: $IsoPath ($isoSize GB)"

# ==================== BUOC 4: PHAT HIEN PARTITION ====================
Write-Step 4 "Phat hien partition layout..."

try {
    $sysDriveLetter = $env:SystemDrive.Substring(0,1)
    $cPartition = Get-Partition -DriveLetter $sysDriveLetter -ErrorAction Stop
    $diskId = $cPartition.DiskNumber
    $partitionId = $cPartition.PartitionNumber
    
    # NEM BUA DINH VI VAO GOC O HE DIEU HANH HIEN TAI (MARKER FAILSAFE)
    $markerPath = "$($sysDriveLetter):\WINAUTO_MARKER.txt"
    "WINAUTO_TARGET_MARKER_DO_NOT_DELETE" | Out-File -FilePath $markerPath -Encoding ASCII -Force
    Write-Ok "Da dat Bua dinh vi tai: $markerPath"

    $disk = Get-Disk -Number $diskId
    $diskSize = [math]::Round($disk.Size / 1GB, 1)
    $diskModel = $disk.FriendlyName
    
    $allPartitions = Get-Partition -DiskNumber $diskId | Sort-Object PartitionNumber
    
    Write-Host ""
    Write-Host "      --- Disk ${diskId} - ${diskModel} (${diskSize} GB) ---" -ForegroundColor Cyan
    foreach ($p in $allPartitions) {
        $pSize = [math]::Round($p.Size / 1GB, 1)
        $pLetter = if ($p.DriveLetter) { "$($p.DriveLetter)" + ":" } else { "  " }
        $pType = $p.Type
        
        if ($p.DriveLetter -eq $sysDriveLetter) {
            Write-Host "      | Partition $($p.PartitionNumber) - $pLetter  $pSize GB  [$pType] -> SE FORMAT" -ForegroundColor Red
        } else {
            Write-Host "      | Partition $($p.PartitionNumber) - $pLetter  $pSize GB  [$pType] -> Giu nguyen" -ForegroundColor Green
        }
    }
    Write-Host "      ----------------------------------------" -ForegroundColor Cyan
    Write-Host ""
    Write-Ok "OS nam o Disk ${diskId}, Partition ${partitionId}"
    
} catch {
    Write-Warn "Khong the phat hien partition C: - $($_.Exception.Message)"
    Read-Host "Nhan Enter de thoat"
    exit 1
}

# ==================== BUOC 5: KIEM TRA SCRIPTS ====================
Write-Step 5 "Kiem tra cac file can thiet..."

$requiredFiles = @(
    @{ Name = "SetupComplete.cmd";  Path = Join-Path $scriptsDir "SetupComplete.cmd" },
    @{ Name = "setup-anydesk.ps1";  Path = Join-Path $scriptsDir "setup-anydesk.ps1" },
    @{ Name = "3dpnet.exe";         Path = Join-Path $scriptsDir "3dpnet.exe" }
)
$optionalFiles = @(
    @{ Name = "AnyDesk.exe (installer)"; Path = Join-Path $scriptsDir "AnyDesk.exe" }
)

$allGood = $true
foreach ($f in $requiredFiles) {
    if (Test-Path $f.Path) {
        Write-Ok "$($f.Name)"
    } else {
        Write-Warn "THIEU: $($f.Name)"
        $allGood = $false
    }
}
foreach ($f in $optionalFiles) {
    if (Test-Path $f.Path) {
        Write-Ok "$($f.Name)"
    } else {
        Write-Host "  [--] $($f.Name) (khong bat buoc)" -ForegroundColor Gray
    }
}

if (-not (Test-Path $templateFile)) {
    Write-Warn "THIEU template: $templateFile"
    $allGood = $false
}

if (-not $allGood) {
    Write-Warn "Thieu file bat buoc! Kiem tra lai thu muc Scripts/"
    Read-Host "Nhan Enter de thoat"
    exit 1
}

# ==================== BUOC 6: XAC NHAN ====================
Write-Host ""
Write-Host "  =====================================================" -ForegroundColor Yellow
Write-Host "  |                 ! XAC NHAN LAN CUOI               |" -ForegroundColor Yellow
Write-Host "  =====================================================" -ForegroundColor Yellow
Write-Host "  | Phien ban : $winVersion" -ForegroundColor Yellow
Write-Host "  | ISO       : $IsoPath" -ForegroundColor Yellow
Write-Host "  | Disk      : ${diskId} ($diskModel)" -ForegroundColor Yellow
Write-Host "  | Partition : ${partitionId} (C)" -ForegroundColor Yellow
Write-Host "  |                                                   |" -ForegroundColor Yellow
Write-Host "  | -> Partition C: SE BI FORMAT                      |" -ForegroundColor Red
Write-Host "  | -> Cac partition khac KHONG bi anh huong          |" -ForegroundColor Green
Write-Host "  | -> May se TU RESTART sau khi xac nhan             |" -ForegroundColor Yellow
Write-Host "  =====================================================" -ForegroundColor Yellow
Write-Host ""

$confirm = Read-Host "  Go 'GO' (viet hoa) de bat dau, hoac Enter de huy"
if ($confirm -ne "GO") {
    Write-Host "  Da huy." -ForegroundColor Gray
    exit 0
}

# ==================== BUOC 7: GIAI NEN ISO ====================
Write-Step 7 "Giai nen ISO..."

if (Test-Path $setupFolder) {
    Write-Host "      Xoa thu muc cu $setupFolder..." -ForegroundColor Gray
    Remove-Item $setupFolder -Recurse -Force
}

New-Item -ItemType Directory -Path $setupFolder -Force | Out-Null

$mountSuccess = $false
try {
    Write-Host "      Thu mount ISO bang Windows..." -ForegroundColor Gray
    $mountResult = Mount-DiskImage -ImagePath $IsoPath -PassThru -ErrorAction Stop
    $isoVolume = $mountResult | Get-Volume
    if ($isoVolume -and $isoVolume.DriveLetter) {
        $isoDrive = "$($isoVolume.DriveLetter):"
        Write-Ok "ISO mounted tai $isoDrive"

        Write-Host "      Dang copy ISO -> $setupFolder (cho 2-5 phut)..." -ForegroundColor Gray
        robocopy "$isoDrive\" "$setupFolder" /E /NFL /NDL /NJH /NJS /NC /NS /NP /R:1 /W:1 | Out-Null
        Write-Ok "Da copy xong"

        Dismount-DiskImage -ImagePath $IsoPath | Out-Null
        Write-Ok "Da unmount ISO"
        $mountSuccess = $true
    } else {
        throw "Mount thanh cong nhung khong lay duoc drive letter"
    }
} catch {
    Write-Host ""
    Write-Host "  [!] Mount ISO that bai: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "  [!] Dang kich hoat PHAO CUU SINH 7-Zip..." -ForegroundColor Yellow
    Write-Host ""

    # Kiem tra 7-Zip da co san chua
    $7zExe = "C:\Program Files\7-Zip\7z.exe"
    if (-not (Test-Path $7zExe)) {
        Write-Host "      Dang tai 7-Zip tu trang chu (1.5 MB)..." -ForegroundColor Gray
        $7zInstaller = Join-Path $env:TEMP "7z_installer.exe"
        try {
            Invoke-WebRequest -Uri "https://www.7-zip.org/a/7z2408-x64.exe" -OutFile $7zInstaller -ErrorAction Stop
            Write-Ok "Da tai 7-Zip installer"

            Write-Host "      Dang cai dat 7-Zip ngam..." -ForegroundColor Gray
            Start-Process -FilePath $7zInstaller -ArgumentList "/S" -Wait
            Write-Ok "Da cai dat 7-Zip"
        } catch {
            Write-Warn "Khong the tai 7-Zip! Kiem tra ket noi mang cua may khach."
            Write-Warn "Hoac cai thu cong 7-Zip roi chay lai script."
            Read-Host "Nhan Enter de thoat"
            exit 1
        }
    } else {
        Write-Ok "7-Zip da co san tren may"
    }

    if (-not (Test-Path $7zExe)) {
        Write-Warn "Khong tim thay 7z.exe sau khi cai dat!"
        Read-Host "Nhan Enter de thoat"
        exit 1
    }

    Write-Host "      Dang giai nen ISO bang 7-Zip (cho 2-5 phut)..." -ForegroundColor Gray
    $extractResult = Start-Process -FilePath $7zExe -ArgumentList "x", "`"$IsoPath`"", "-o`"$setupFolder`"", "-y" -Wait -PassThru -NoNewWindow
    if ($extractResult.ExitCode -ne 0) {
        Write-Warn "7-Zip giai nen that bai! File ISO co the bi loi."
        Read-Host "Nhan Enter de thoat"
        exit 1
    }
    Write-Ok "Da giai nen ISO bang 7-Zip thanh cong"
    $mountSuccess = $true
}

if (-not $mountSuccess) {
    Write-Warn "Khong the giai nen ISO bang bat ky phuong phap nao!"
    Read-Host "Nhan Enter de thoat"
    exit 1
}

# ==================== BUOC 8: TAO $OEM$ VA COPY SCRIPTS ====================
Write-Step 8 "Tao $OEM$ va copy scripts..."

$oemScriptsPath = Join-Path $setupFolder "sources\`$OEM`$\`$`$\Setup\Scripts"
New-Item -ItemType Directory -Path $oemScriptsPath -Force | Out-Null

$scriptFiles = Get-ChildItem -Path $scriptsDir -File
foreach ($f in $scriptFiles) {
    Copy-Item $f.FullName $oemScriptsPath -Force
    Write-Host "      -> $($f.Name)" -ForegroundColor Gray
}
Write-Ok "Da copy $($scriptFiles.Count) files"

# ==================== BUOC 9: SINH XML ====================
Write-Step 9 "Sinh autounattend.xml..."

$xmlContent = Get-Content $templateFile -Raw -Encoding UTF8
$xmlContent = $xmlContent -replace '{{DISK_ID}}', $diskId
$xmlContent = $xmlContent -replace '{{PARTITION_ID}}', $partitionId

$outputXml = Join-Path $setupFolder "autounattend.xml"
$xmlContent | Out-File -FilePath $outputXml -Encoding UTF8 -Force
Write-Ok "Da tao autounattend.xml"

# ==================== BUOC 10: CHAY SETUP ====================
Write-Step 10 "Khoi chay Windows Setup..."
Write-Host ""
Write-Warn "MAY SE TU RESTART TRONG GIAY LAT!"
Write-Warn "Ban se MAT KET NOI REMOTE - do la binh thuong."
Write-Warn "Cho 15-30 phut -> nhan Telegram."
Write-Host ""

Start-Sleep -Seconds 3

$setupExe = Join-Path $setupFolder "sources\setup.exe"
if (-not (Test-Path $setupExe)) {
    $setupExe = Join-Path $setupFolder "setup.exe"
}
if (-not (Test-Path $setupExe)) {
    Write-Warn "LOI: Khong tim thay setup.exe trong file ISO vua giai nen!"
    Read-Host "Nhan Enter de thoat"
    exit 1
}
Write-Host "      Bat dau downlevel phase..." -ForegroundColor Gray
Start-Process -FilePath $setupExe -ArgumentList "/unattend:`"$outputXml`"" -Wait

Write-Host "  Setup da ket thuc hoac may dang restart..." -ForegroundColor Cyan
