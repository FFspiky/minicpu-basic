$ErrorActionPreference = "Continue"

$LogDir = "D:\CPU_DESIGN\wsl_repair_logs"
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
$Stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$LogPath = Join-Path $LogDir "wsl_repair_$Stamp.log"

Start-Transcript -Path $LogPath -Force

function Section($Title) {
    Write-Host ""
    Write-Host "============================================================"
    Write-Host $Title
    Write-Host "============================================================"
}

Section "Admin Check"
$IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
Write-Host "Administrator: $IsAdmin"
if (-not $IsAdmin) {
    Write-Host "This script must run as Administrator."
    Stop-Transcript
    exit 1
}

Section "System And WSL State Before Repair"
systeminfo | Select-String -Pattern "OS 名称|OS 版本|系统型号|基于虚拟化的安全性|Hyper-V 要求|虚拟"
wsl --version
wsl --status
wsl -l -v

Section "Optional Features Before Repair"
dism.exe /online /get-featureinfo /featurename:Microsoft-Windows-Subsystem-Linux
dism.exe /online /get-featureinfo /featurename:VirtualMachinePlatform
dism.exe /online /get-featureinfo /featurename:HypervisorPlatform

Section "Service And File Checks Before Repair"
Get-Service WSLService,LxssManager,vmcompute,hns -ErrorAction SilentlyContinue | Format-Table Name,Status,StartType,DisplayName -AutoSize
reg query HKLM\SYSTEM\CurrentControlSet\Services\vmcompute
reg query HKLM\SYSTEM\CurrentControlSet\Services\hns
Write-Host "vmcompute.exe exists:" (Test-Path "$env:SystemRoot\System32\vmcompute.exe")
Write-Host "hns.exe exists:" (Test-Path "$env:SystemRoot\System32\hns.exe")

Section "Component Store Repair"
DISM.exe /Online /Cleanup-Image /RestoreHealth

Section "System File Repair"
sfc /scannow

Section "Re-enable Required Windows Features"
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
dism.exe /online /enable-feature /featurename:HypervisorPlatform /all /norestart
bcdedit /set hypervisorlaunchtype auto

Section "Update WSL Package"
wsl --update
wsl --shutdown

Section "State After Repair"
dism.exe /online /get-featureinfo /featurename:Microsoft-Windows-Subsystem-Linux
dism.exe /online /get-featureinfo /featurename:VirtualMachinePlatform
dism.exe /online /get-featureinfo /featurename:HypervisorPlatform
Get-Service WSLService,LxssManager,vmcompute,hns -ErrorAction SilentlyContinue | Format-Table Name,Status,StartType,DisplayName -AutoSize
wsl --version
wsl --status
wsl -l -v

Section "Next Step"
Write-Host "Log saved to: $LogPath"
Write-Host "If DISM/SFC repaired files or feature enabling reported pending changes, reboot once."
Write-Host "After reboot, run: ubuntu2404"

Stop-Transcript
