# ================================================================
# Phase 6: Join Domain
# ================================================================
param([PSCustomObject]$State, [PSCustomObject]$Config)

$phaseNum = 6
Write-Log "===== PHASE $phaseNum: JOIN DOMAIN =====" -Level PHASE

$domainName = $Config.domain.name
$ouPath = $Config.domain.ou
$joinAccount = $State.domainJoinAccount
$joinPassword = Unprotect-Secret $State.domainJoinPassword

if ([string]::IsNullOrEmpty($domainName)) {
    Write-Log "Domain name trong config.json bi trong!" -Level ERROR
    Complete-Phase -State $State -CurrentPhase $phaseNum -Message "No domain name"
    return
}

if ([string]::IsNullOrEmpty($joinAccount) -or [string]::IsNullOrEmpty($joinPassword)) {
    Write-Log "Domain join credentials bi trong!" -Level ERROR
    Complete-Phase -State $State -CurrentPhase $phaseNum -Message "No domain join credentials"
    return
}

# Kiem tra da join domain chua
$currentDomain = (Get-WmiObject Win32_ComputerSystem).Domain
Write-Log "Domain hien tai: $currentDomain" -Level INFO

if ($currentDomain -eq $domainName) {
    Write-Log "May da join domain '$domainName' roi" -Level OK
    Complete-Phase -State $State -CurrentPhase $phaseNum -Message "Already joined $domainName"
    return
}

# ==================== JOIN DOMAIN ====================
Write-Log "Dang join domain '$domainName'..." -Level INFO
Write-Log "Join account: $joinAccount" -Level INFO

try {
    $secPassword = ConvertTo-SecureString $joinPassword -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential ("$domainName\$joinAccount", $secPassword)
    
    $joinParams = @{
        DomainName = $domainName
        Credential = $credential
        Force      = $true
        ErrorAction = "Stop"
    }
    
    # Them OU neu co cau hinh
    if (-not [string]::IsNullOrEmpty($ouPath)) {
        $joinParams.OUPath = $ouPath
        Write-Log "OU Path: $ouPath" -Level INFO
    }
    
    Add-Computer @joinParams
    Write-Log "Join domain thanh cong!" -Level OK
    
} catch {
    Write-Log "Join domain THAT BAI: $($_.Exception.Message)" -Level ERROR
    
    # Thu lai voi ten domain NETBIOS
    $netbiosDomain = $domainName.Split('.')[0]
    Write-Log "Thu lai voi NETBIOS domain: $netbiosDomain..." -Level WARN
    
    try {
        $credential2 = New-Object System.Management.Automation.PSCredential ("$netbiosDomain\$joinAccount", $secPassword)
        Add-Computer -DomainName $domainName -Credential $credential2 -Force -ErrorAction Stop
        Write-Log "Join domain thanh cong (NETBIOS)!" -Level OK
    } catch {
        Write-Log "Join domain van THAT BAI: $($_.Exception.Message)" -Level ERROR
    }
}

# ==================== HOAN TAT ====================
# Join domain BAT BUOC restart
Complete-Phase -State $State -CurrentPhase $phaseNum -Message "Domain join attempted: $domainName"
