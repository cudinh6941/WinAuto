# ================================================================
# prepare.ps1 - WinAuto v2 - Script chinh chuan bi cai lai Windows
# Chay script nay tren may can cai lai. No se:
#   1. Hoi thong tin cau hinh cho may nay
#   2. Phat hien partition C: (DiskID, PartitionID)
#   3. Giai nen ISO, tao $OEM$, copy scripts
#   4. Sinh autounattend.xml dung cho may
#   5. Luu state.json + Tao Scheduled Task
#   6. Chay setup.exe -> may tu cai lai
# ================================================================

param(
    [string]$IsoPath
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$setupFolder = "C:\WinSetup"

# Load thu vien
$libDir = Join-Path $scriptDir "Scripts\lib"
if (Test-Path (Join-Path $libDir "common.ps1")) {
    . (Join-Path $libDir "common.ps1")
}

# ==================== HAM TIEN ICH ====================
function Write-Banner {
    Write-Host ""
    Write-Host "  =====================================================" -ForegroundColor Cyan
    Write-Host "  |      WinAuto v2 - Batch Windows Deployment         |" -ForegroundColor Cyan
    Write-Host "  |    Developed by Pham Kha Dinh - PTSC Quang Ngai    |" -ForegroundColor Cyan
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

function Test-AdminLocal {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# ==================== KIEM TRA QUYEN ADMIN ====================
Write-Banner

if (-not (Test-AdminLocal)) {
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
    Write-Host "      Script da gai Bua Dinh Vi (Marker Failsafe) de bao ve tuyet doi o Data." -ForegroundColor Yellow
    Write-Host ""
} else {
    Write-Ok "So luong o cung: 1 (An toan tuyet doi)"
}

# ==================== BUOC 1: NHAP THONG TIN MAY ====================
Write-Host ""
Write-Host "  =====================================================" -ForegroundColor Magenta
Write-Host "  |           NHAP THONG TIN CHO MAY NAY              |" -ForegroundColor Magenta
Write-Host "  =====================================================" -ForegroundColor Magenta
Write-Host ""

# 1. Computer name
do {
    $computerName = Read-Host "  [1] Computer name (VD: PKDINH)"
    $computerName = $computerName.Trim().ToUpper()
} while ([string]::IsNullOrEmpty($computerName))
Write-Ok "Computer name: $computerName"

# 2. Domain username
do {
    $domainUsername = Read-Host "  [2] Domain username (VD: pkdinh)"
    $domainUsername = $domainUsername.Trim()
} while ([string]::IsNullOrEmpty($domainUsername))
Write-Ok "Domain username: $domainUsername"

# 3. Domain user password
do {
    $domainUserPassword = Read-Host "  [3] Password cho $domainUsername"
} while ([string]::IsNullOrEmpty($domainUserPassword))
Write-Ok "Password: ********"

# 4. Windows version
Write-Host "  [4] Chon phien ban Windows:" -ForegroundColor White
Write-Host "      [10] Windows 10" -ForegroundColor White
Write-Host "      [11] Windows 11 (co bypass TPM/SecureBoot)" -ForegroundColor White
do {
    $winChoice = Read-Host "      Nhap 10 hoac 11"
} while ($winChoice -ne "10" -and $winChoice -ne "11")

if ($winChoice -eq "10") {
    $winVersion = "10"
    $templateFile = Join-Path $scriptDir "autounattend_win10.xml"
} else {
    $winVersion = "11"
    $templateFile = Join-Path $scriptDir "autounattend_win11.xml"
}
Write-Ok "Windows: $winVersion"

# 5. Kaspersky
do {
    $kasChoice = Read-Host "  [5] Cai Kaspersky? (Y/N)"
    $kasChoice = $kasChoice.Trim().ToUpper()
} while ($kasChoice -ne "Y" -and $kasChoice -ne "N")
$installKaspersky = ($kasChoice -eq "Y")
Write-Ok "Kaspersky: $(if ($installKaspersky) {'Co'} else {'Khong'})"

# 6. Office
Write-Host "  [6] Chon phien ban Office:" -ForegroundColor White
Write-Host "      [365]  Office 365" -ForegroundColor White
Write-Host "      [2016] Office 2016" -ForegroundColor White
do {
    $officeChoice = Read-Host "      Nhap 365 hoac 2016"
} while ($officeChoice -ne "365" -and $officeChoice -ne "2016")
$officeType = $officeChoice
Write-Ok "Office: $officeType"

# 7. Domain join account
do {
    $domainJoinAccount = Read-Host "  [7] Tai khoan join domain (VD: admin_join)"
    $domainJoinAccount = $domainJoinAccount.Trim()
} while ([string]::IsNullOrEmpty($domainJoinAccount))
Write-Ok "Join account: $domainJoinAccount"

# 8. Domain join password
do {
    $domainJoinPassword = Read-Host "  [8] Password join domain"
} while ([string]::IsNullOrEmpty($domainJoinPassword))
Write-Ok "Join password: ********"

Write-Host ""

# ==================== BUOC 2: CAU HINH WIFI ====================
Write-Step 2 "Cau hinh ket noi mang sau khi cai xong:"
Write-Host "      Doc tu config.json..." -ForegroundColor Gray

# Doc config.json de kiem tra WiFi
$configPath = Join-Path $scriptDir "config.json"
if (Test-Path $configPath) {
    $config = Get-Content $configPath -Raw | ConvertFrom-Json
    if ($config.network.wifi.enabled) {
        Write-Ok "WiFi: $($config.network.wifi.ssid) (tu config.json)"
    } else {
        Write-Ok "WiFi: Tat - dung LAN"
    }
} else {
    Write-Warn "Khong tim thay config.json!"
    Read-Host "Nhan Enter de thoat"
    exit 1
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

$scriptsDir = Join-Path $scriptDir "Scripts"
$requiredFiles = @(
    @{ Name = "SetupComplete.cmd";   Path = Join-Path $scriptsDir "SetupComplete.cmd" },
    @{ Name = "post-install.ps1";    Path = Join-Path $scriptsDir "post-install.ps1" },
    @{ Name = "lib\common.ps1";      Path = Join-Path $scriptsDir "lib\common.ps1" },
    @{ Name = "lib\network.ps1";     Path = Join-Path $scriptsDir "lib\network.ps1" }
)
$optionalFiles = @(
    @{ Name = "3dpnet.exe";          Path = Join-Path $scriptsDir "3dpnet.exe" }
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

# Kiem tra phase scripts
$phaseFiles = 1..9 | ForEach-Object { "phases\phase$_-*.ps1" }
$phasesDir = Join-Path $scriptsDir "phases"
if (Test-Path $phasesDir) {
    $phaseCount = (Get-ChildItem -Path $phasesDir -Filter "phase*.ps1" -File).Count
    Write-Ok "Phase scripts: $phaseCount files"
} else {
    Write-Warn "THIEU: Thu muc phases/"
    $allGood = $false
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
Write-Host "  | Computer   : $computerName" -ForegroundColor Yellow
Write-Host "  | Domain User: $domainUsername" -ForegroundColor Yellow
Write-Host "  | Windows    : $winVersion" -ForegroundColor Yellow
Write-Host "  | Office     : $officeType" -ForegroundColor Yellow
Write-Host "  | Kaspersky  : $(if ($installKaspersky) {'Co'} else {'Khong'})" -ForegroundColor Yellow
Write-Host "  | ISO        : $IsoPath" -ForegroundColor Yellow
Write-Host "  | Disk       : ${diskId} ($diskModel)" -ForegroundColor Yellow
Write-Host "  | Partition  : ${partitionId} (${sysDriveLetter}:)" -ForegroundColor Yellow
Write-Host "  |                                                   |" -ForegroundColor Yellow
Write-Host "  | -> Partition ${sysDriveLetter}: SE BI FORMAT                      |" -ForegroundColor Red
Write-Host "  | -> Cac partition khac KHONG bi anh huong          |" -ForegroundColor Green
Write-Host "  | -> May se TU RESTART va TU DONG CAI DAT          |" -ForegroundColor Yellow
Write-Host "  =====================================================" -ForegroundColor Yellow
Write-Host ""

$confirm = Read-Host "  Go 'GO' (viet hoa) de bat dau, hoac Enter de huy"
if ($confirm -ne "GO") {
    Write-Host "  Da huy." -ForegroundColor Gray
    exit 0
}

# ==================== BUOC 7: LUU STATE ====================
Write-Step 7 "Luu state.json..."

# Load DPAPI
Add-Type -AssemblyName System.Security -ErrorAction SilentlyContinue

$stateData = New-WinAutoState `
    -ComputerName $computerName `
    -DomainUsername $domainUsername `
    -DomainUserPassword $domainUserPassword `
    -WinVersion $winVersion `
    -InstallKaspersky $installKaspersky `
    -OfficeType $officeType `
    -DomainJoinAccount $domainJoinAccount `
    -DomainJoinPassword $domainJoinPassword

Write-Ok "State da luu tai $($script:StateFile)"

# ==================== BUOC 8: TAO SCHEDULED TASK ====================
Write-Step 8 "Tao Scheduled Task cho auto-resume..."
Register-WinAutoTask
Write-Ok "Scheduled Task WinAuto_Resume da tao"

# ==================== BUOC 9: GIAI NEN ISO ====================
Write-Step 9 "Giai nen ISO..."

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

# ==================== BUOC 10: TAO $OEM$ VA COPY SCRIPTS ====================
Write-Step 10 "Tao `$OEM`$ va copy scripts..."

$oemScriptsPath = Join-Path $setupFolder "sources\`$OEM`$\`$`$\Setup\Scripts"
New-Item -ItemType Directory -Path $oemScriptsPath -Force | Out-Null

# Copy tat ca files trong Scripts/ (bao gom subdirectories)
$scriptFiles = Get-ChildItem -Path $scriptsDir -File
foreach ($f in $scriptFiles) {
    Copy-Item $f.FullName $oemScriptsPath -Force
    Write-Host "      -> $($f.Name)" -ForegroundColor Gray
}

# Copy thu muc lib/ va phases/
$subDirs = @("lib", "phases")
foreach ($subDir in $subDirs) {
    $srcDir = Join-Path $scriptsDir $subDir
    $dstDir = Join-Path $oemScriptsPath $subDir
    if (Test-Path $srcDir) {
        New-Item -ItemType Directory -Path $dstDir -Force | Out-Null
        Copy-Item "$srcDir\*" $dstDir -Recurse -Force
        $count = (Get-ChildItem -Path $dstDir -File -Recurse).Count
        Write-Host "      -> $subDir/ ($count files)" -ForegroundColor Gray
    }
}

Write-Ok "Da copy scripts va subdirectories"

# ==================== BUOC 11: SINH XML ====================
Write-Step 11 "Sinh autounattend.xml..."

$xmlContent = Get-Content $templateFile -Raw -Encoding UTF8
$xmlContent = $xmlContent -replace '{{DISK_ID}}', $diskId
$xmlContent = $xmlContent -replace '{{PARTITION_ID}}', $partitionId

$outputXml = Join-Path $setupFolder "autounattend.xml"
$xmlContent | Out-File -FilePath $outputXml -Encoding UTF8 -Force
Write-Ok "Da tao autounattend.xml"

# ==================== BUOC 12: CHAY SETUP ====================
Write-Step 12 "Khoi chay Windows Setup..."
Write-Host ""
Write-Warn "MAY SE TU RESTART TRONG GIAY LAT!"
Write-Warn "Sau khi cai xong, may se TU DONG thuc hien 9 buoc:"
Write-Host "      Phase 1: Cai driver mang + Ket noi" -ForegroundColor Gray
Write-Host "      Phase 2: Upgrade len Windows Pro" -ForegroundColor Gray
Write-Host "      Phase 3: Doi ten may + Join domain" -ForegroundColor Gray
Write-Host "      Phase 4: Add domain user $domainUsername" -ForegroundColor Gray
Write-Host "      Phase 5: Tat BitLocker" -ForegroundColor Gray
Write-Host "      Phase 6: Cai Office $officeType" -ForegroundColor Gray
Write-Host "      Phase 7: Cai Custom Apps" -ForegroundColor Gray
Write-Host "      Phase 8: Cai Kaspersky$(if (-not $installKaspersky) {' (BO QUA)'})" -ForegroundColor Gray
Write-Host "      Phase 9: Hoan tat + Switch user" -ForegroundColor Gray
Write-Host ""
Write-Warn "Khong can lam gi them. Co the bo di sang may khac."
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
