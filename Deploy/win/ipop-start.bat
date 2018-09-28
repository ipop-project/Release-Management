@echo off
set py=''
call :CheckForPython  > nul 2>&1
if ERRORLEVEL 1 (
  echo A Python 3.5 installation was not found on this system, please install it
  goto end
  )

start /B ipop-tincan.exe > logs\tincan.log 2>&1
timeout /t 3 /nobreak  > nul 2>&1
start /B "ipop-controller" "%py%" -m controller.Controller -c config/ipop-config.json > logs\ctrl.log 2>&1
echo IPOP-VPN was started, see the logs directory for details. Press Ctl+Break to terminate.
goto end

REM ---------------------------------------------------------------------------
:CheckForPython
set command='reg query hkcu\software\python\pythoncore\3.5\installpath /v ExecutablePath'
for /f "tokens=1,2* delims= " %%i in (%command%) do @set py=%%k
if NOT "%py%"=="''" exit /B 0
set command='reg query hklm\software\python\pythoncore\3.5\installpath /v ExecutablePath'
for /f "tokens=1,2* delims= " %%i in (%command%) do @set py=%%k
if NOT "%py%"=="''" exit /B 0
set command='reg query hklm\software\Wow6432Node\python\pythoncore\3.5\installpath /v ExecutablePath'
for /f "tokens=1,2* delims= " %%i in (%command%) do @set py=%%k
if NOT "%py%"=="''" exit /B 0
exit /B 1

:end
