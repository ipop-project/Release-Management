$cwd=split-path -parent $MyInvocation.MyCommand.Definition
$py3_url='https://www.python.org/ftp/python/3.5.2/python-3.5.2-amd64-webinstall.exe'
$tap_url='https://swupdate.openvpn.org/community/releases/tap-windows-9.21.2.exe'
$msvcr_url='https://download.microsoft.com/download/5/B/C/5BC5DBB3-652D-4DCE-B14A-475AB85EEF6E/vcredist_x86.exe'
$download_dir="$cwd\temp"
$config_dir="$cwd\config"
$log_dir="$cwd\logs"
$cfg_file="$config_dir\ipop-config.json"
$py=''

#PowerShell.exe -ExecutionPolicy Unrestricted
#$ErrorActionPreference= 'silentlycontinue'

#------------------------------------------------------------------------------
function MakeDirs {
 if (!(Test-Path $download_dir)){ mkdir $download_dir}
 if (!(Test-Path $log_dir)){ mkdir $log_dir}
 if (!(Test-Path $config_dir)){ mkdir $config_dir}
}

#------------------------------------------------------------------------------
function GetMSVCR {
 $resp=Read-Host -Prompt 'Install Microsoft Visual C++ 2010 Redistributable Package (x86) [y]? '
 if ($resp -eq 'y') {
  if (!(Test-Path %download_dir%\vcredist_x86.exe)) {
   'Downloading VC Redistributable 2010.'
   Invoke-WebRequest $msvcr_url -OutFile "$download_dir\vcredist_x86.exe"
  }
 & "$download_dir\vcredist_x86.exe"
 }
}

#------------------------------------------------------------------------------
function GetTap {
 $resp=Read-Host -Prompt 'Install TAP NDIS driver 9.21.2 for Windows [y]? '
 if($resp -eq 'y') {
  if (!(Test-Path %download_dir%\tap-windows-9.21.2.exe)) {
   'Downloading Open VPN TAP Driver.'
   Invoke-WebRequest $tap_url -OutFile "$download_dir\tap-windows-9.21.2.exe"
  }
  & "$download_dir\tap-windows-9.21.2.exe"
 }
}

#------------------------------------------------------------------------------
function GetPython {
 $resp=Read-Host -Prompt 'Install Python 3.5.2 for Windows [y]? '
 if ($resp -eq 'y') {
  if (!(Test-Path $download_dir%\python-3.5.2-amd64-webinstall.exe)) {
   'Downloading Python 3.'
   Invoke-WebRequest $py3_url -OutFile "$download_dir\python-3.5.2-amd64-webinstall.exe"
  }
 & "$download_dir\python-3.5.2-amd64-webinstall.exe"
 }
}

#------------------------------------------------------------------------------
function SetupConfig {
 Do {
  $resp=Read-Host -Prompt 'Configure IPOP for GroupVPN or SocialVPN [g/s]? '
  if ($resp -eq 'g') {
   $src="$cwd\controller\modules\sample-gvpn-config.json"
  } elseif ($resp -eq 's') {
     $src="$cwd\controller\modules\sample-svpn-config.json"
  } else {
     'Invalid response, please try again ...'
  }
 } While (!($resp -eq 'g') -and !($resp -eq 's'))

 if ((Test-Path $cfg_file)) {
  $resp=Read-Host -Prompt 'A config file already exist do you want to use it [y]? '
  if (!($resp -eq 'y')) {
   $dt=Get-Date -Format FileDateTime
   Rename-Item $cfg_file -NewName "config$dt.json"
    if (!(Test-Path $src)) {
     "Could not locate a sample config file, please create one and save as $cfg_file"
    } else {
       Copy-Item $src -Destination $cfg_file
    }
  }
 } else {
    Copy-Item $src -Destination $cfg_file
 }
 'Edit your config file and then save and exit notepad'
 notepad $cfg_file
 pause
}

#------------------------------------------------------------------------------
function SetupTapInterface {
 $py=CheckForPython
 if ($py -eq 'python') {
    'No Python found, resorting to PATH environment'
 }
 Get-NetAdapter | Where-Object -FilterScript {$_.InterfaceDescription -eq 'TAP-Windows Adapter V9'} | Rename-NetAdapter -newname ipop
 (Get-Content $cfg_file) -Join "`n" |ConvertFrom-Json -OutVariable jcfg > $null
 if ($jcfg.CFx.ip4_mask -eq 8) {
  $mask='255.0.0.0'
 } elseif ($jcfg.CFx.ip4_mask -eq 16) {
  $mask='255.255.0.0'
 } elseif ($jcfg.CFx.ip4_mask -eq 24) {
  $mask='255.255.255.0'
 }
 & netsh interface ip set address ipop static $jcfg.CFx.ip4 $mask
 & netsh interface ipv4 set subinterface ipop 'mtu=1280' 'store=persistent'
 #Below doesn't work if the adapter is disconnected, Set-Net* will only update active state
 #Set-NetIPInterface -InterfaceAlias ipop -Dhcp Disabled -NlMtuBytes 1280 -PolicyStore PersistentStore
 #Remove-NetIPAddress -InterfaceAlias ipop -Confirm:$false
 #New-NetIPAddress -InterfaceAlias ipop –IPAddress $jcfg.CFx.ip4 –PrefixLength $jcfg.CFx.ip4_mask
}

function InstallSleekXmpp {
 $resp=Read-Host -Prompt 'Install Sleek XMPP for Python [y]? '
 if ($resp -eq 'y') {
  $py=CheckForPython
  $pip= Split-Path -Parent $py
  & "$pip\Scripts\pip.exe" install sleekxmpp
 }
}
#------------------------------------------------------------------------------
function DeleteDownloads {
 $resp=Read-Host -Prompt 'Delete downloaded setup files [y]? '
 if ($resp -eq 'y') {
  Remove-Item -Recurse -Force $download_dir
 }
}

#------------------------------------------------------------------------------
function CheckForPython {
 $paths="hkcu:\software\python\pythoncore\3.5\installpath", "hklm:\software\python\pythoncore\3.5\installpath", "hklm:\software\Wow6432Node\python\pythoncore\3.5\installpath"
 $regvalue='ExecutablePath'
 ForEach($path in $paths){
  if (Test-RegistryValue -Path $path -Value $regvalue) {
   $pyinfo=Get-ItemProperty -Path $path -Name $regvalue
   break
  }
 }
 if (!($pyinfo -eq '')) { $py=$pyinfo.ExecutablePath}
  else { $py='python'}

 $py
}

#------------------------------------------------------------------------------
function Test-RegistryValue {
 param (
  [parameter(Mandatory=$true)]
  [ValidateNotNullOrEmpty()]$Path,
  [parameter(Mandatory=$true)]
  [ValidateNotNullOrEmpty()]$Value
 )
 try {
 Get-ItemProperty -Path $Path -ErrorAction Stop | Select-Object -ExpandProperty $Value -ErrorAction Stop > $null
  return $true
 }
 catch {
  return $false
 }
}

#------------------------------------------------------------------------------
MakeDirs
GetMSVCR
GetTap
GetPython
SetupConfig
SetupTapInterface
InstallSleekXmpp
DeleteDownloads

'Setup completed! Run ipop-start to start IPOP'
pause
