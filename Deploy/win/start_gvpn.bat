start /B ipop-tincan.exe > logs\tincan.log 2>&1
ping 1.1.1.1 -n 1 -w 3000 > null
set PATH=%PATH%;C:\Python27
start /B /WAIT python -m controller.Controller -c config/gvpn-config.json > logs\ctrl.log 2>&1
pause
