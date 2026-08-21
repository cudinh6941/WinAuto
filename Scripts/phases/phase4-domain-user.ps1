param([PSCustomObject]$State, [PSCustomObject]$Config)

. "$PSScriptRoot\..\lib\common.ps1"

Write-Log "===== BAT DAU PHASE 4: ADD DOMAIN USER VAO LOCAL ADMINS =====" -Level PHASE
Send-PhaseNotification -ComputerName $State.computerName -Phase 4 -Status "start" -Message "Add domain user $($State.domainUsername)"

$dryRun = Test-DryRun
$domainName = $Config.domain.name
$domainUser = $State.domainUsername

if ([string]::IsNullOrEmpty($domainUser)) {
    Write-Log "Khong co domain username trong state!" -Level ERROR
    Skip-Phase -State $State -CurrentPhase 4 -Reason "Thieu domain username"
    return
}

$fullUsername = "$domainName\$domainUser"
Write-Log "Domain user: $fullUsername" -Level INFO

# ==================== CHECK DA LA MEMBER CHUA ====================
try {
    $admGroup = Get-LocalGroupMember -Group "Administrators" -ErrorAction Stop
    $alreadyMember = $admGroup | Where-Object { $_.Name -like "*\$domainUser" }
    
    if ($alreadyMember) {
        Write-Log "$fullUsername da la member cua Administrators - BO QUA" -Level OK
        Skip-Phase -State $State -CurrentPhase 4 -Reason "Da la Administrator"
        return
    }
} catch {
    Write-Log "Khong doc duoc group Administrators: $($_.Exception.Message)" -Level WARN
}

# ==================== ADD DOMAIN USER ====================
if ($dryRun) {
    Write-DryRun "SE CHAY: Add-LocalGroupMember -Group 'Administrators' -Member '$fullUsername'"
    Complete-Phase -State $State -CurrentPhase 4 -Message "[DRY-RUN] Add domain user"
    return
}

try {
    Invoke-WithRetry -OperationName "Add Domain User" -MaxRetries 3 -DelaySeconds 10 -ScriptBlock {
        Add-LocalGroupMember -Group "Administrators" -Member $fullUsername -ErrorAction Stop
        Write-Log "Da add $fullUsername vao Administrators thanh cong!" -Level OK
    }
} catch {
    Write-Log "Loi add user: $($_.Exception.Message)" -Level ERROR
    
    # Thu voi format khac: user@domain
    $upnUser = "$domainUser@$domainName"
    Write-Log "Thu lai voi UPN format: $upnUser..." -Level INFO
    try {
        Add-LocalGroupMember -Group "Administrators" -Member $upnUser -ErrorAction Stop
        Write-Log "Da add $upnUser vao Administrators thanh cong!" -Level OK
    } catch {
        Write-Log "Van that bai voi UPN: $($_.Exception.Message)" -Level ERROR
        Send-PhaseNotification -ComputerName $State.computerName -Phase 4 -Status "error" -Message "Khong add duoc $domainUser vao Admins"
    }
}

Complete-Phase -State $State -CurrentPhase 4 -Message "Domain user $domainUser added to Administrators"
