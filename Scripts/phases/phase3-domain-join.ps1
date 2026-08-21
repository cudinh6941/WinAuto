param([PSCustomObject]$State, [PSCustomObject]$Config)

. "$PSScriptRoot\..\lib\common.ps1"

Write-Log "===== BAT DAU PHASE 3: RENAME + JOIN DOMAIN =====" -Level PHASE
Send-PhaseNotification -ComputerName $State.computerName -Phase 3 -Status "start" -Message "Doi ten may + Join domain $($Config.domain.name)"

$dryRun = Test-DryRun
$domainName = $Config.domain.name
$ouPath = $Config.domain.ou
$dcIP = $Config.domain.dcIP
$dnsServers = $Config.domain.dnsServers
$newName = $State.computerName

# ==================== BUILD CREDENTIAL ====================
$joinAccount = $State.domainJoinAccount
$joinPassword = Unprotect-Secret $State.domainJoinPassword

if ([string]::IsNullOrEmpty($joinAccount) -or [string]::IsNullOrEmpty($joinPassword)) {
    Write-Log "Thieu thong tin tai khoan join domain!" -Level ERROR
    Send-PhaseNotification -ComputerName $newName -Phase 3 -Status "error" -Message "Thieu credential join domain"
    return
}

# Them domain prefix neu chua co
if ($joinAccount -notmatch '\\') {
    $joinAccount = "$domainName\$joinAccount"
}

$secPassword = ConvertTo-SecureString $joinPassword -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($joinAccount, $secPassword)

Write-Log "Join account: $joinAccount" -Level INFO
Write-Log "Domain: $domainName" -Level INFO
Write-Log "OU: $ouPath" -Level INFO
Write-Log "New name: $newName" -Level INFO

# ==================== CHECK DA JOIN DOMAIN CHUA ====================
$currentDomain = (Get-WmiObject Win32_ComputerSystem).Domain
$currentName = $env:COMPUTERNAME

Write-Log "May hien tai: $currentName, Domain/Workgroup: $currentDomain" -Level INFO

if ($currentDomain -eq $domainName -and $currentName -eq $newName) {
    Write-Log "May da join domain $domainName voi ten $newName roi - BO QUA" -Level OK
    Skip-Phase -State $State -CurrentPhase 3 -Reason "Da join domain dung ten"
    return
}

# ==================== FIX DNS TRO VE DC ====================
Write-Log "Kiem tra DNS resolve $domainName..." -Level INFO

$dnsOk = $false
try {
    $resolved = Resolve-DnsName $domainName -ErrorAction Stop
    if ($resolved) {
        Write-Log "DNS resolve OK: $($resolved[0].IPAddress)" -Level OK
        $dnsOk = $true
    }
} catch {
    Write-Log "DNS khong resolve duoc $domainName" -Level WARN
}

if (-not $dnsOk -and $dnsServers -and $dnsServers.Count -gt 0) {
    Write-Log "Set DNS manual ve DC: $($dnsServers -join ', ')" -Level INFO
    
    if ($dryRun) {
        Write-DryRun "SE SET DNS adapters ve: $($dnsServers -join ', ')"
    } else {
        # Tim adapter dang active
        $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
        foreach ($adapter in $adapters) {
            try {
                Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses $dnsServers
                Write-Log "Da set DNS cho adapter '$($adapter.Name)'" -Level OK
            } catch {
                Write-Log "Loi set DNS cho '$($adapter.Name)': $($_.Exception.Message)" -Level WARN
            }
        }
        
        # Clear DNS cache
        Clear-DnsClientCache -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 3
        
        # Verify lai
        try {
            $resolved = Resolve-DnsName $domainName -ErrorAction Stop
            Write-Log "DNS resolve OK sau khi set manual: $($resolved[0].IPAddress)" -Level OK
            $dnsOk = $true
        } catch {
            Write-Log "VAN KHONG RESOLVE DUOC $domainName sau khi set DNS!" -Level ERROR
        }
    }
}

# ==================== PING DC ====================
Write-Log "Ping DC tai $dcIP..." -Level INFO
$pingOk = Test-Connection -ComputerName $dcIP -Count 2 -Quiet -ErrorAction SilentlyContinue
if ($pingOk) {
    Write-Log "Ping DC OK!" -Level OK
} else {
    Write-Log "KHONG PING DUOC DC tai $dcIP!" -Level ERROR
    if (-not $dryRun) {
        Send-PhaseNotification -ComputerName $newName -Phase 3 -Status "error" -Message "Khong ping duoc DC $dcIP"
    }
}

# ==================== JOIN DOMAIN + RENAME ====================
if ($dryRun) {
    Write-DryRun "SE CHAY: Add-Computer -DomainName $domainName -NewName $newName -OUPath '$ouPath' -Credential *** -Force -Restart"
    Complete-Phase -State $State -CurrentPhase 3 -Message "[DRY-RUN] Join domain + rename"
    return
}

Write-Log "Bat dau join domain (retry toi da 5 lan, moi lan cach 30s)..." -Level INFO

try {
    Invoke-WithRetry -OperationName "Join Domain" -MaxRetries 5 -DelaySeconds 30 -ScriptBlock {
        $addParams = @{
            DomainName = $domainName
            NewName    = $newName
            Credential = $credential
            Force      = $true
            ErrorAction = "Stop"
        }
        
        # Chi them OUPath neu co config
        if (-not [string]::IsNullOrEmpty($ouPath)) {
            $addParams.OUPath = $ouPath
        }
        
        Add-Computer @addParams
        Write-Log "Add-Computer thanh cong!" -Level OK
    }
    
    Send-PhaseNotification -ComputerName $newName -Phase 3 -Status "complete" -Message "Da join domain $domainName thanh cong"
    
} catch {
    $errorMsg = $_.Exception.Message
    Write-Log "JOIN DOMAIN THAT BAI SAU 5 LAN: $errorMsg" -Level ERROR
    Send-PhaseNotification -ComputerName $newName -Phase 3 -Status "error" -Message "Join domain that bai: $errorMsg"
    
    # KHONG goi Complete-Phase → giu nguyen currentPhase = 3
    # Lan restart sau se thu lai
    Write-Log "Phase 3 SE THU LAI sau khi restart!" -Level WARN
    
    # Van restart de thu lai
    Start-Sleep -Seconds 5
    Restart-Computer -Force
    return
}

Complete-Phase -State $State -CurrentPhase 3 -Message "Rename + Join domain hoan tat"
