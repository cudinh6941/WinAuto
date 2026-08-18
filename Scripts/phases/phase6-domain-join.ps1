param([PSCustomObject]$State, [PSCustomObject]$Config)
Write-Host "   >>> DANG CHAY PHASE 6 GIA LAP <<<" -ForegroundColor Green
Start-Sleep -Seconds 1
. "$PSScriptRoot\..\lib\common.ps1"
Complete-Phase -State $State -CurrentPhase 6 -Message "Mock phase 6 hoan tat"
