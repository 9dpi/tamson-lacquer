@echo off
rem ====================================================
rem  Wrapper chay update.bat commit tu Task Scheduler
rem  (duoc lap lich moi ngay 08:00 boi Task Scheduler)
rem ====================================================
set "PATH=C:\Program Files\Git\cmd;%PATH%"
cd /d "%~dp0"
call "%~dp0update.bat" commit
