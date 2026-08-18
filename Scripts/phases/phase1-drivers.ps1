param([PSCustomObject]$State, [PSCustomObject]$Config)
Write-Host "   >>> DANG CHAY PHASE 1 GIA LAP <<<" -ForegroundColor Green
Start-Sleep -Seconds 1
. "$PSScriptRoot\..\lib\common.ps1"
Complete-Phase -State $State -CurrentPhase 1 -Message "Mock phase 1 hoan tat"
