param([PSCustomObject]$State, [PSCustomObject]$Config)
Write-Host "   >>> DANG CHAY PHASE 4 GIA LAP <<<" -ForegroundColor Green
Start-Sleep -Seconds 1
. "$PSScriptRoot\..\lib\common.ps1"
Complete-Phase -State $State -CurrentPhase 4 -Message "Mock phase 4 hoan tat"
