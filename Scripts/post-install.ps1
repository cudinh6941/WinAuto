# ================================================================
# post-install.ps1 - Phase Executor chinh cua WinAuto v2
# Chay tu dong sau moi lan restart, doc state.json de biet
# dang o phase nao va tiep tuc chay phase tiep theo.
# ================================================================

$ErrorActionPreference = "Continue"

# ==================== LOAD THU VIEN ====================
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$libDir = Join-Path $scriptDir "lib"
$phasesDir = Join-Path $scriptDir "phases"

# Import common functions
. (Join-Path $libDir "common.ps1")
. (Join-Path $libDir "network.ps1")

# ==================== DOC STATE ====================
$state = Get-WinAutoState

if (-not $state) {
    # Khong co state file = khong co gi de lam
    "[$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))] [ERROR] post-install.ps1: Khong tim thay file state.json! Script dung lai." | Out-File "C:\WinAuto_setup.log" -Append
    exit 0
}

# ==================== KHOI TAO LOG ====================
$logFile = Initialize-Log -ComputerName $state.computerName

Write-Log "==========================================" -Level PHASE
Write-Log "WinAuto v2 - Post-Install Phase Executor" -Level PHASE
Write-Log "Computer: $($state.computerName)" -Level PHASE
Write-Log "Current Phase: $($state.currentPhase)" -Level PHASE
Write-Log "==========================================" -Level PHASE

# ==================== DOC CONFIG ====================
$config = Get-WinAutoConfig

if (-not $config) {
    Write-Log "KHONG DOC DUOC config.json! Dung lai." -Level ERROR
    exit 1
}

# ==================== CHO HE THONG ON DINH ====================
Write-Log "Cho he thong on dinh (20s)..." -Level INFO
Start-Sleep -Seconds 20

# ==================== CHAY PHASES ====================
$totalPhases = 9

function Invoke-Phase {
    param([int]$PhaseNumber)
    
    if ($PhaseNumber -gt $totalPhases) {
        Write-Log "Tat ca phases da hoan tat!" -Level PHASE
        return
    }
    
    $phaseScript = switch ($PhaseNumber) {
        1 { Join-Path $phasesDir "phase1-drivers.ps1" }
        2 { Join-Path $phasesDir "phase2-upgrade-pro.ps1" }
        3 { Join-Path $phasesDir "phase3-office.ps1" }
        4 { Join-Path $phasesDir "phase4-kaspersky.ps1" }
        5 { Join-Path $phasesDir "phase5-rename.ps1" }
        6 { Join-Path $phasesDir "phase6-domain-join.ps1" }
        7 { Join-Path $phasesDir "phase7-domain-user.ps1" }
        8 { Join-Path $phasesDir "phase8-custom-apps.ps1" }
        9 { Join-Path $phasesDir "phase9-finalize.ps1" }
        default { $null }
    }
    
    if (-not $phaseScript -or -not (Test-Path $phaseScript)) {
        Write-Log "Phase script khong ton tai: $phaseScript" -Level ERROR
        return
    }
    
    Write-Log "Chay phase $PhaseNumber tu: $phaseScript" -Level INFO
    
    try {
        # Doc lai state moi nhat truoc khi chay phase
        $currentState = Get-WinAutoState
        
        # Chay phase script
        . $phaseScript -State $currentState -Config $config
        
        # Sau khi phase chay xong (neu khong restart), chay phase tiep
        $updatedState = Get-WinAutoState
        if ($updatedState -and $updatedState.currentPhase -gt $PhaseNumber) {
            Invoke-Phase -PhaseNumber $updatedState.currentPhase
        }
    } catch {
        Write-Log "LOI NGHIEM TRONG tai Phase ${PhaseNumber}: $($_.Exception.Message)" -Level ERROR
        Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level ERROR
        
        # Ghi loi vao state
        $errorState = Get-WinAutoState
        if ($errorState) {
            Add-PhaseLog -State $errorState -Phase $PhaseNumber -Status "error" -Message $_.Exception.Message
        }
        
        # Van tiep tuc phase tiep theo (khong de 1 phase loi lam dung het)
        Write-Log "Bo qua Phase $PhaseNumber do loi, tiep tuc Phase $($PhaseNumber + 1)..." -Level WARN
        $errorState = Get-WinAutoState
        if ($errorState) {
            $errorState.currentPhase = $PhaseNumber + 1
            Set-WinAutoState -State $errorState
            Invoke-Phase -PhaseNumber ($PhaseNumber + 1)
        }
    }
}

# Bat dau tu phase hien tai trong state
Invoke-Phase -PhaseNumber $state.currentPhase


