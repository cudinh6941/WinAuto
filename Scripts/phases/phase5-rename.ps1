# ================================================================
# Phase 5: Doi ten may tinh + Rename local admin account
# ================================================================
param([PSCustomObject]$State, [PSCustomObject]$Config)

$phaseNum = 5
Write-Log "===== PHASE $phaseNum: DOI TEN MAY + RENAME LOCAL ADMIN =====" -Level PHASE

$newName = $State.computerName

if ([string]::IsNullOrEmpty($newName)) {
    Write-Log "Computer name trong state.json bi trong!" -Level ERROR
    Complete-Phase -State $State -CurrentPhase $phaseNum -Message "No computer name"
    return
}

$currentName = $env:COMPUTERNAME
Write-Log "Ten may hien tai: $currentName" -Level INFO
Write-Log "Ten may moi: $newName" -Level INFO

# ==================== DOI TEN MAY ====================
if ($currentName -ne $newName) {
    Write-Log "Dang doi ten may tu '$currentName' thanh '$newName'..." -Level INFO
    try {
        Rename-Computer -NewName $newName -Force -ErrorAction Stop
        Write-Log "Rename-Computer thanh cong!" -Level OK
    } catch {
        Write-Log "Rename-Computer that bai: $($_.Exception.Message)" -Level ERROR
        # Thu cach khac
        try {
            $computer = Get-WmiObject Win32_ComputerSystem
            $result = $computer.Rename($newName)
            if ($result.ReturnValue -eq 0) {
                Write-Log "WMI Rename thanh cong!" -Level OK
            } else {
                Write-Log "WMI Rename that bai, return code: $($result.ReturnValue)" -Level ERROR
            }
        } catch {
            Write-Log "WMI Rename cung that bai: $($_.Exception.Message)" -Level ERROR
        }
    }
} else {
    Write-Log "Ten may da dung, khong can doi" -Level OK
}

# ==================== RENAME LOCAL ADMIN ACCOUNT ====================
# Tim tai khoan local admin hien tai (co the la "Administrator" hoac "User")
Write-Log "Dang rename local admin account thanh '$newName'..." -Level INFO

$adminAccounts = @("Administrator", "User")
$renamed = $false

foreach ($adminName in $adminAccounts) {
    $account = Get-LocalUser -Name $adminName -ErrorAction SilentlyContinue
    if ($account) {
        # Khong rename neu da dung ten
        if ($adminName -eq $newName) {
            Write-Log "Account '$adminName' da dung ten, khong can rename" -Level OK
            $renamed = $true
            break
        }
        
        try {
            Rename-LocalUser -Name $adminName -NewName $newName -ErrorAction Stop
            Write-Log "Da rename account '$adminName' thanh '$newName'" -Level OK
            $renamed = $true
            break
        } catch {
            Write-Log "Rename '$adminName' that bai: $($_.Exception.Message)" -Level WARN
        }
    }
}

if (-not $renamed) {
    Write-Log "Khong tim thay tai khoan admin de rename (thu: $($adminAccounts -join ', '))" -Level WARN
}

# ==================== HOAN TAT ====================
# Rename-Computer BAT BUOC restart
Complete-Phase -State $State -CurrentPhase $phaseNum -Message "Renamed: $currentName -> $newName"
