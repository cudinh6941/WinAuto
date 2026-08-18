param([PSCustomObject]$State, [PSCustomObject]$Config)
Write-Host "   >>> DANG CHAY PHASE 3 GIA LAP <<<" -ForegroundColor Green
Start-Sleep -Seconds 1
. "$PSScriptRoot\..\lib\common.ps1"
Complete-Phase -State $State -CurrentPhase 3 -Message "Mock phase 3 hoan tat"
