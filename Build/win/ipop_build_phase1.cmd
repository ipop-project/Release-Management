gclient --version
gclient --version
git config --global core.autocrlf false
git config --global core.filemode false
git config --global branch.autosetuprebase always

mkdir libjingle
cd libjingle

set DEPOT_TOOLS_WIN_TOOLCHAIN=0
set GYP_GENERATORS=ninja
set GYP_MSVS_VERSION=2013e

gclient config --name=trunk http://webrtc.googlecode.com/svn/branches/3.52

gclient sync --force
gclient sync --force

cd trunk\talk
mkdir ipop-project
cd ipop-project
git clone --depth 1 https://github.com/ipop-project/ipop-tap.git
git clone --depth 1 https://github.com/ipop-project/ipop-tincan.git

cd ..\..

del all.gyp talk\libjingle.gyp
copy talk\ipop-project\ipop-tincan\build\ipop-tincan.gyp talk\
copy talk\ipop-project\ipop-tincan\build\libjingle.gyp talk\
copy talk\ipop-project\ipop-tincan\build\all.gyp .

copy C:\Users\ipopuser\workspace\Pre-built.2\ C:\Users\ipopuser\workspace\libjingle\trunk\third_party\pthreads_win32

mkdir C:\Users\ipopuser\workspace\libjingle\trunk\talk\ipop-project\ipop-tap\bin
copy C:\Users\ipopuser\workspace\ipop-dll\ipoptap.dll C:\Users\ipopuser\workspace\libjingle\trunk\talk\ipop-project\ipop-tap\bin
copy C:\Users\ipopuser\workspace\ipop-dll\ipoptap.def C:\Users\ipopuser\workspace\libjingle\trunk\talk\ipop-project\ipop-tap\bin

cd C:\Users\ipopuser\workspace\libjingle\trunk\talk\ipop-project\ipop-tap\bin
"c:\Program Files (x86)\Microsoft Visual Studio 12.0\VC\bin\lib.exe" /def:ipoptap.def
