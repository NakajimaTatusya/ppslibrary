@echo off

REM Navigate to your source file directory.
cd /d %~dp0

REM get date.
for /f "tokens=1-4 delims=/ " %%i in ("%date%") do (
 set year=%%i
 set month=%%j
 set day=%%k
)
REM get time.
set time_tmp=%time: =0%
set hh=%time_tmp:~0,2%
set mi=%time_tmp:~3,2%
set ss=%time_tmp:~6,2%
set sss=%time_tmp:~9,2%

set datetimestr=%year%%month%%day%_%hh%%mi%%ss%%sss%
REM echo datetimestr = %datetimestr%

REM make a relative file path for logs.
set IMPORTLOGFILE=.\logs\Cli-Kintone-imp-BAT_%datetimestr%.log

REM ####################↓↓↓ IMPORT ↓↓↓####################
REM Execute a PowerShell script.
REM ALL
REM PowerShell -NoProfile -ExecutionPolicy Unrestricted -File Import-Clikintone.ps1 -batmode import 1> %IMPORTLOGFILE% 2>&1 3>&1 4>&1 5>&1 6>&1
REM APPLICATION 1
REM PowerShell -NoProfile -ExecutionPolicy Unrestricted -File Import-Clikintone.ps1 -batmode import -application "import csv with attachments files" 1> %IMPORTLOGFILE% 2>&1 3>&1 4>&1 5>&1 6>&1
REM APPLICATION 2
REM PowerShell -NoProfile -ExecutionPolicy Unrestricted -File Import-Clikintone.ps1 -batmode import -application "cli-kintone import csv data" 1> %IMPORTLOGFILE% 2>&1 3>&1 4>&1 5>&1 6>&1
REM APPLICATION 3
REM PowerShell -NoProfile -ExecutionPolicy Unrestricted -File Import-Clikintone.ps1 -batmode import -application "Dummy1" 1> %IMPORTLOGFILE% 2>&1 3>&1 4>&1 5>&1 6>&1
REM APPLICATION 4
PowerShell -NoProfile -ExecutionPolicy Unrestricted -File Import-Clikintone.ps1 -batmode import -application "testapp4" 1> %IMPORTLOGFILE% 2>&1 3>&1 4>&1 5>&1 6>&1
REM ####################↑↑↑ IMPORT ↑↑↑####################

if not %ERRORLEVEL%==0 (Exit /b 1) else (Exit /b 0)
