@echo off
:: SetupComplete.cmd - Chay tu dong sau khi Windows cai xong (WinAuto v2)
:: File nay phai nam tai: C:\Windows\Setup\Scripts\SetupComplete.cmd

echo [%date% %time%] SetupComplete.cmd bat dau chay >> C:\WinAuto_setup.log

:: Dang ky Scheduled Task de chay kien tri qua nhung lan khoi dong
echo [%date% %time%] Dang ky WinAuto_Resume Task... >> C:\WinAuto_setup.log
powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -Command ". 'C:\Windows\Setup\Scripts\lib\common.ps1'; Register-WinAutoTask" >> C:\WinAuto_setup.log 2>&1

echo [%date% %time%] SetupComplete.cmd da chay xong >> C:\WinAuto_setup.log