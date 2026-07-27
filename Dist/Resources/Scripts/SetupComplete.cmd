@echo off
:: SetupComplete.cmd - Chay tu dong sau khi Windows cai xong
:: File nay phai nam tai: C:\Windows\Setup\Scripts\SetupComplete.cmd

echo [%date% %time%] SetupComplete.cmd bat dau chay >> C:\WinAuto_setup.log

call "C:\Windows\Setup\Scripts\setup-anydesk.cmd"

echo [%date% %time%] SetupComplete.cmd da chay xong >> C:\WinAuto_setup.log