set cwd=%~dp0
set PATH=%PATH%;C:\Python27
python "%cwd%\win32_netsh_setup.py" "%cwd%config\config.json"
pause
