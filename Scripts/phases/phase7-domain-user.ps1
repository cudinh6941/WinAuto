# ================================================================
# Phase 7: Add domain user vao local Administrators
# ================================================================
param([PSCustomObject]$State, [PSCustomObject]$Config)

$phaseNum = 7
Write-Log "===== PHASE $phaseNum: ADD DOMAIN USER =====" -Level PHASE

$domainName = $Config.domain.name
$domainUsername = $State.domainUsername

if ([string]::IsNullOrEmpty($domainUsername)) {
    Write-Log "Domain username trong state.json bi trong!" -Level ERROR
    Complete-Phase -State $State -CurrentPhase $phaseNum -Message "No domain username"
    return
}

# Lay NETBIOS domain name
$netbiosDomain = $domainName.Split('.')[0]
$fullDomainUser = "$netbiosDomain\$domainUsername"

Write-Log "Domain user: $fullDomainUser" -Level INFO

# ==================== ADD USER VAO LOCAL ADMINISTRATORS ====================
Write-Log "Dang add '$fullDomainUser' vao nhom Administrators..." -Level INFO

try {
    # Thu dung cmdlet moi truoc
    Add-LocalGroupMember -Group "Administrators" -Member $fullDomainUser -ErrorAction Stop
    Write-Log "Da add '$fullDomainUser' vao Administrators" -Level OK
} catch {
    if ($_.Exception.Message -match "already a member") {
        Write-Log "'$fullDomainUser' da la thanh vien cua Administrators" -Level OK
    } else {
        Write-Log "Add-LocalGroupMember that bai: $($_.Exception.Message)" -Level WARN
        
        # Fallback: net localgroup
        Write-Log "Thu net localgroup..." -Level INFO
        try {
            $result = net localgroup Administrators "$fullDomainUser" /add 2>&1
            Write-Log "net localgroup: $result" -Level INFO
        } catch {
            Write-Log "net localgroup cung that bai: $($_.Exception.Message)" -Level ERROR
        }
    }
}

# ==================== KIEM TRA ====================
$members = Get-LocalGroupMember -Group "Administrators" -ErrorAction SilentlyContinue
if ($members) {
    Write-Log "Thanh vien nhom Administrators:" -Level INFO
    foreach ($m in $members) {
        Write-Log "  - $($m.Name) ($($m.ObjectClass))" -Level INFO
    }
}

# ==================== HOAN TAT ====================
Complete-Phase -State $State -CurrentPhase $phaseNum -Message "Domain user '$fullDomainUser' added to Administrators"
