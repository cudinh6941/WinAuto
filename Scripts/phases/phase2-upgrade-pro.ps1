# ================================================================
# Phase 2: Upgrade Windows Home -> Pro bang product key
# ================================================================
param([PSCustomObject]$State, [PSCustomObject]$Config)

$phaseNum = 2
Write-Log "===== PHASE $phaseNum: UPGRADE WINDOWS HOME -> PRO =====" -Level PHASE

# Xac dinh product key theo phien ban
$proKey = if ($State.winVersion -eq "10") {
    $Config.upgrade.win10ProKey
} else {
    $Config.upgrade.win11ProKey
}

if ([string]::IsNullOrEmpty($proKey)) {
    Write-Log "Khong tim thay product key Pro trong config.json" -Level ERROR
    Complete-Phase -State $State -CurrentPhase $phaseNum -Message "No Pro key found, skipped"
    return
}

# Kiem tra da la Pro chua
$currentEdition = (Get-WindowsEdition -Online).Edition
Write-Log "Edition hien tai: $currentEdition" -Level INFO

if ($currentEdition -match "Professional|Pro|Enterprise") {
    Write-Log "Da la ban Pro/Enterprise, bo qua upgrade" -Level OK
    Complete-Phase -State $State -CurrentPhase $phaseNum -Message "Already Pro: $currentEdition"
    return
}

# Thu upgrade bang changepk.exe truoc (nhanh hon, co GUI progress)
Write-Log "Dang upgrade len Pro bang changepk.exe..." -Level INFO
$changepk = "$env:SystemRoot\System32\changepk.exe"

if (Test-Path $changepk) {
    try {
        Start-Process -FilePath $changepk -ArgumentList "/ProductKey $proKey" -Wait -ErrorAction Stop
        Write-Log "changepk.exe da chay xong" -Level OK
    } catch {
        Write-Log "changepk.exe that bai: $($_.Exception.Message). Thu slmgr..." -Level WARN
        
        # Fallback: slmgr
        try {
            $slmgrResult = cscript //nologo "$env:SystemRoot\System32\slmgr.vbs" /ipk $proKey 2>&1
            Write-Log "slmgr /ipk: $slmgrResult" -Level INFO
        } catch {
            Write-Log "slmgr cung that bai: $($_.Exception.Message)" -Level ERROR
        }
    }
} else {
    # Fallback: slmgr
    Write-Log "changepk.exe khong ton tai, dung slmgr..." -Level WARN
    try {
        $slmgrResult = cscript //nologo "$env:SystemRoot\System32\slmgr.vbs" /ipk $proKey 2>&1
        Write-Log "slmgr /ipk: $slmgrResult" -Level INFO
    } catch {
        Write-Log "slmgr that bai: $($_.Exception.Message)" -Level ERROR
    }
}

# Cho he thong xu ly upgrade (co the mat vai phut)
Write-Log "Cho he thong xu ly upgrade edition (60s)..." -Level INFO
Start-Sleep -Seconds 60

# Verify
$newEdition = (Get-WindowsEdition -Online).Edition
Write-Log "Edition sau upgrade: $newEdition" -Level INFO

# ==================== HOAN TAT ====================
Complete-Phase -State $State -CurrentPhase $phaseNum -Message "Edition upgrade: $currentEdition -> $newEdition"
