# ================================================================
# common.ps1 - Thu vien ham dung chung cho WinAuto v2
# Bao gom: Logging, State Management, Reboot Detection, Encryption
# ================================================================

function Get-WinAutoRoot {
    $drives = Get-Volume | Where-Object DriveLetter
    foreach ($d in $drives) {
        $path = "$($d.DriveLetter):\WinAuto"
        if (Test-Path (Join-Path $path "state.json")) {
            return $path
        }
    }
    return "D:\WinAuto" # fallback
}

$script:WinAutoRoot = Get-WinAutoRoot
$script:StateFile = Join-Path $script:WinAutoRoot "state.json"
$script:ConfigFile = Join-Path $script:WinAutoRoot "config.json"
$script:LogDir = Join-Path $script:WinAutoRoot "Logs"

# ==================== LOGGING ====================
function Initialize-Log {
    param([string]$ComputerName = $env:COMPUTERNAME)
    
    if (-not (Test-Path $script:LogDir)) {
        New-Item -ItemType Directory -Path $script:LogDir -Force | Out-Null
    }
    
    $date = Get-Date -Format "yyyy-MM-dd"
    $script:LogFile = Join-Path $script:LogDir "${ComputerName}_${date}.log"
    
    # Tao file log neu chua co
    if (-not (Test-Path $script:LogFile)) {
        "" | Out-File -FilePath $script:LogFile -Encoding UTF8
    }
    
    return $script:LogFile
}

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "OK", "WARN", "ERROR", "PHASE")]
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$timestamp] [$Level] $Message"
    
    # Ghi file
    if ($script:LogFile -and (Test-Path (Split-Path $script:LogFile -Parent))) {
        Add-Content -Path $script:LogFile -Value $entry -Force -ErrorAction SilentlyContinue
    }
    
    # Hien thi console
    $color = switch ($Level) {
        "OK"    { "Green" }
        "WARN"  { "Yellow" }
        "ERROR" { "Red" }
        "PHASE" { "Cyan" }
        default { "White" }
    }
    Write-Host $entry -ForegroundColor $color
}

# ==================== STATE MANAGEMENT ====================
function Get-WinAutoState {
    if (Test-Path $script:StateFile) {
        try {
            $content = Get-Content $script:StateFile -Raw -Encoding UTF8
            return $content | ConvertFrom-Json
        } catch {
            Write-Log "Loi doc state.json: $($_.Exception.Message)" -Level ERROR
            return $null
        }
    }
    return $null
}

function Set-WinAutoState {
    param([PSCustomObject]$State)
    try {
        $State | ConvertTo-Json -Depth 10 | Out-File -FilePath $script:StateFile -Encoding UTF8 -Force
        Write-Log "State saved: Phase $($State.currentPhase)" -Level INFO
    } catch {
        Write-Log "Loi ghi state.json: $($_.Exception.Message)" -Level ERROR
    }
}

function New-WinAutoState {
    param(
        [string]$ComputerName,
        [string]$DomainUsername,
        [string]$DomainUserPassword,
        [string]$WinVersion,
        [bool]$InstallKaspersky,
        [string]$OfficeType,
        [string]$DomainJoinAccount,
        [string]$DomainJoinPassword
    )
    
    $state = [PSCustomObject]@{
        currentPhase       = 1
        computerName       = $ComputerName
        domainUsername      = $DomainUsername
        domainUserPassword  = (Protect-Secret $DomainUserPassword)
        winVersion         = $WinVersion
        installKaspersky   = $InstallKaspersky
        officeType         = $OfficeType
        domainJoinAccount  = $DomainJoinAccount
        domainJoinPassword  = (Protect-Secret $DomainJoinPassword)
        startTime          = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        phaseLog           = @()
    }
    
    Set-WinAutoState -State $state
    return $state
}

function Add-PhaseLog {
    param(
        [PSCustomObject]$State,
        [int]$Phase,
        [string]$Status,
        [string]$Message = ""
    )
    
    $logEntry = [PSCustomObject]@{
        phase   = $Phase
        status  = $Status
        time    = (Get-Date -Format "HH:mm:ss")
        message = $Message
    }
    
    # Convert to array if needed, add entry
    $logs = @($State.phaseLog) + $logEntry
    $State.phaseLog = $logs
    
    Set-WinAutoState -State $State
}

# ==================== CONFIG MANAGEMENT ====================
function Get-WinAutoConfig {
    if (Test-Path $script:ConfigFile) {
        try {
            $content = Get-Content $script:ConfigFile -Raw -Encoding UTF8
            return $content | ConvertFrom-Json
        } catch {
            Write-Log "Loi doc config.json: $($_.Exception.Message)" -Level ERROR
            return $null
        }
    }
    Write-Log "Khong tim thay config.json tai $($script:ConfigFile)" -Level ERROR
    return $null
}

# ==================== PASSWORD ENCRYPTION (DPAPI) ====================
function Protect-Secret {
    param([string]$PlainText)
    if ([string]::IsNullOrEmpty($PlainText)) { return "" }
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($PlainText)
        $encrypted = [System.Security.Cryptography.ProtectedData]::Protect(
            $bytes, $null, [System.Security.Cryptography.DataProtectionScope]::LocalMachine
        )
        return [Convert]::ToBase64String($encrypted)
    } catch {
        Write-Log "DPAPI Protect failed: $($_.Exception.Message)" -Level WARN
        # Fallback: Base64 encode (khong an toan, nhung van hoat dong)
        return "B64:" + [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($PlainText))
    }
}

function Unprotect-Secret {
    param([string]$EncryptedText)
    if ([string]::IsNullOrEmpty($EncryptedText)) { return "" }
    try {
        # Check fallback Base64
        if ($EncryptedText.StartsWith("B64:")) {
            $b64 = $EncryptedText.Substring(4)
            return [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($b64))
        }
        
        $encrypted = [Convert]::FromBase64String($EncryptedText)
        $bytes = [System.Security.Cryptography.ProtectedData]::Unprotect(
            $encrypted, $null, [System.Security.Cryptography.DataProtectionScope]::LocalMachine
        )
        return [System.Text.Encoding]::UTF8.GetString($bytes)
    } catch {
        Write-Log "DPAPI Unprotect failed: $($_.Exception.Message)" -Level ERROR
        return ""
    }
}

# ==================== PENDING REBOOT DETECTION ====================
function Test-PendingReboot {
    $reasons = @()
    
    # 1. Component Based Servicing
    if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending") {
        $reasons += "CBS RebootPending"
    }
    
    # 2. Windows Update
    if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired") {
        $reasons += "Windows Update"
    }
    
    # 3. Pending File Rename Operations
    $pfro = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name PendingFileRenameOperations -ErrorAction SilentlyContinue
    if ($pfro -ne $null -and $pfro.PendingFileRenameOperations.Count -gt 0) {
        $reasons += "PendingFileRename"
    }
    
    # 4. Computer Name changed
    try {
        $activeName = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ActiveComputerName" -ErrorAction Stop).ComputerName
        $pendingName = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName" -ErrorAction Stop).ComputerName
        if ($activeName -ne $pendingName) {
            $reasons += "ComputerName changed ($activeName -> $pendingName)"
        }
    } catch { }
    
    # 5. Domain join pending
    if (Test-Path "HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\JoinDomain") {
        $reasons += "Domain Join Pending"
    }
    
    if ($reasons.Count -gt 0) {
        Write-Log "Pending reboot detected: $($reasons -join ', ')" -Level WARN
        return $true
    }
    
    return $false
}

# ==================== PHASE EXECUTION HELPERS ====================
function Complete-Phase {
    param(
        [PSCustomObject]$State,
        [int]$CurrentPhase,
        [string]$Message = ""
    )
    
    Write-Log "===== Phase $CurrentPhase HOAN TAT =====" -Level PHASE
    Add-PhaseLog -State $State -Phase $CurrentPhase -Status "completed" -Message $Message
    
    # Cap nhat phase tiep theo
    $State.currentPhase = $CurrentPhase + 1
    Set-WinAutoState -State $State
    
    if (Test-PendingReboot) {
        Write-Log "He thong can RESTART. Se tu dong tiep tuc Phase $($CurrentPhase + 1) sau khi restart." -Level WARN
        Start-Sleep -Seconds 3
        Restart-Computer -Force
        # Script dung tai day
        Start-Sleep -Seconds 60
        exit 0
    } else {
        Write-Log "Khong can restart. Chay tiep Phase $($CurrentPhase + 1)..." -Level INFO
    }
}

function Skip-Phase {
    param(
        [PSCustomObject]$State,
        [int]$CurrentPhase,
        [string]$Reason = "Skipped by config"
    )
    
    Write-Log "===== Phase $CurrentPhase BO QUA: $Reason =====" -Level PHASE
    Add-PhaseLog -State $State -Phase $CurrentPhase -Status "skipped" -Message $Reason
    
    $State.currentPhase = $CurrentPhase + 1
    Set-WinAutoState -State $State
}

# ==================== SCHEDULED TASK ====================
function Register-WinAutoTask {
    $taskName = "WinAuto_Resume"
    
    # Xoa task cu neu co
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    
    $postInstallScript = "C:\Windows\Setup\Scripts\post-install.ps1"
    
    $action = New-ScheduledTaskAction -Execute "powershell.exe" `
        -Argument "-ExecutionPolicy Bypass -WindowStyle Normal -File `"$postInstallScript`""
    
    # Trigger: Khi bat ky user nao logon, delay 15 giay
    $trigger = New-ScheduledTaskTrigger -AtLogOn
    $trigger.Delay = "PT15S"
    
    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable `
        -ExecutionTimeLimit (New-TimeSpan -Hours 4)
    
    # Chay Interactive (hien thi cua so) duoi quyen nhom Administrators
    $principal = New-ScheduledTaskPrincipal -GroupId "BUILTIN\Administrators" -RunLevel Highest
    
    Register-ScheduledTask -TaskName $taskName `
        -Action $action `
        -Trigger $trigger `
        -Settings $settings `
        -Principal $principal `
        -Description "WinAuto v2 - Tu dong tiep tuc cai dat sau khi restart" `
        -Force | Out-Null
    
    Write-Log "Scheduled Task '$taskName' da duoc tao" -Level OK
}

function Unregister-WinAutoTask {
    $taskName = "WinAuto_Resume"
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    Write-Log "Scheduled Task '$taskName' da duoc xoa" -Level OK
}

# ==================== ADMIN CHECK ====================
function Test-Admin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# ==================== INTERNET CHECK ====================
function Test-Internet {
    try {
        $result = Test-Connection -ComputerName "8.8.8.8" -Count 1 -Quiet -ErrorAction SilentlyContinue
        return $result
    } catch {
        return $false
    }
}

# ==================== TELEGRAM ====================
function Send-TelegramMessage {
    param(
        [string]$Message,
        [string]$BotToken,
        [string]$ChatId
    )
    
    if ([string]::IsNullOrEmpty($BotToken) -or [string]::IsNullOrEmpty($ChatId)) {
        Write-Log "Telegram: Thieu BotToken hoac ChatId" -Level WARN
        return $false
    }
    
    $url = "https://api.telegram.org/bot$BotToken/sendMessage"
    $body = @{ chat_id = $ChatId; text = $Message; parse_mode = "HTML" } | ConvertTo-Json -Compress
    
    for ($i = 1; $i -le 3; $i++) {
        try {
            $null = Invoke-RestMethod -Uri $url -Method Post -Body $body `
                -ContentType "application/json; charset=utf-8" -TimeoutSec 30
            Write-Log "Telegram: Gui thanh cong (lan $i)" -Level OK
            return $true
        } catch {
            Write-Log "Telegram: Lan $i that bai - $($_.Exception.Message)" -Level WARN
            if ($i -lt 3) { Start-Sleep -Seconds 10 }
        }
    }
    Write-Log "Telegram: DA THU 3 LAN - KHONG GUI DUOC" -Level ERROR
    return $false
}

# Load DPAPI assembly
Add-Type -AssemblyName System.Security -ErrorAction SilentlyContinue
