start ipop-tincan.exe
ping 1.1.1.1 -n 1 -w 3000 > nul
set PATH=%PATH%;C:\Python27
python -m controller.Controller -c config/gvpn-config.json
pause
