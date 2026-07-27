$b64 = (Get-Content D:\WinAuto\Dist\WinAuto.cmd -Raw) -split '##BASE64_START##\r?\n' | Select-Object -Last 1
$bytes = [Convert]::FromBase64String($b64.Trim())
$code = [System.Text.Encoding]::Unicode.GetString($bytes)
$code | Out-File -FilePath D:\WinAuto\Dist\decoded.ps1 -Encoding UTF8
