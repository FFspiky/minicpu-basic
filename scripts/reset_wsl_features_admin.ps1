$ErrorActionPreference = "Continue"

$LogDir = "D:\CPU_DESIGN\wsl_repair_logs"
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
$Stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$LogPath = Join-Path $LogDir "wsl_feature_reset_$Stamp.log"

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
    Stop-Transcript
    exit 1
}

Section "Before"
dism.exe /online /get-featureinfo /featurename:VirtualMachinePlatform
dism.exe /online /get-featureinfo /featurename:Microsoft-Windows-Subsystem-Linux
dism.exe /online /get-featureinfo /featurename:HypervisorPlatform
Get-Service WSLService,LxssManager,vmcompute,hns -ErrorAction SilentlyContinue | Format-Table Name,Status,StartType,DisplayName -AutoSize
Write-Host "vmcompute.exe exists:" (Test-Path "$env:SystemRoot\System32\vmcompute.exe")
Write-Host "hns.exe exists:" (Test-Path "$env:SystemRoot\System32\hns.exe")

Section "Toggle VirtualMachinePlatform"
dism.exe /online /disable-feature /featurename:VirtualMachinePlatform /norestart
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart

Section "Ensure WSL And Hypervisor Settings"
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
dism.exe /online /enable-feature /featurename:HypervisorPlatform /all /norestart
bcdedit /set hypervisorlaunchtype Auto
wsl --shutdown
wsl --update

Section "After"
dism.exe /online /get-featureinfo /featurename:VirtualMachinePlatform
dism.exe /online /get-featureinfo /featurename:Microsoft-Windows-Subsystem-Linux
dism.exe /online /get-featureinfo /featurename:HypervisorPlatform
Get-Service WSLService,LxssManager,vmcompute,hns -ErrorAction SilentlyContinue | Format-Table Name,Status,StartType,DisplayName -AutoSize
Write-Host "vmcompute.exe exists:" (Test-Path "$env:SystemRoot\System32\vmcompute.exe")
Write-Host "hns.exe exists:" (Test-Path "$env:SystemRoot\System32\hns.exe")

Section "Next Step"
Write-Host "Log saved to: $LogPath"
Write-Host "Reboot once after this feature reset, then run: ubuntu2404"

Stop-Transcript
