param([PSCustomObject]$State, [PSCustomObject]$Config)
Write-Host "   >>> DANG CHAY PHASE 2 GIA LAP <<<" -ForegroundColor Green
Start-Sleep -Seconds 1
. "$PSScriptRoot\..\lib\common.ps1"
Complete-Phase -State $State -CurrentPhase 2 -Message "Mock phase 2 hoan tat"
