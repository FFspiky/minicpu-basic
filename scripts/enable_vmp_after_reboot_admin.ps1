$ErrorActionPreference = "Continue"

$LogDir = "D:\CPU_DESIGN\wsl_repair_logs"
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
$Stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$LogPath = Join-Path $LogDir "wsl_enable_vmp_$Stamp.log"

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
Get-Service WSLService,LxssManager,vmcompute,hns -ErrorAction SilentlyContinue |
    Format-Table Name,Status,StartType,DisplayName -AutoSize
Write-Host "vmcompute.exe exists:" (Test-Path "$env:SystemRoot\System32\vmcompute.exe")
Write-Host "hns.exe exists:" (Test-Path "$env:SystemRoot\System32\hns.exe")

Section "Enable Required Features"
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
Write-Host "VirtualMachinePlatform enable exit code: $LASTEXITCODE"
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
Write-Host "WSL feature enable exit code: $LASTEXITCODE"
dism.exe /online /enable-feature /featurename:HypervisorPlatform /all /norestart
Write-Host "HypervisorPlatform enable exit code: $LASTEXITCODE"
bcdedit /set hypervisorlaunchtype Auto
Write-Host "bcdedit exit code: $LASTEXITCODE"

Section "After"
dism.exe /online /get-featureinfo /featurename:VirtualMachinePlatform
dism.exe /online /get-featureinfo /featurename:Microsoft-Windows-Subsystem-Linux
dism.exe /online /get-featureinfo /featurename:HypervisorPlatform
Get-Service WSLService,LxssManager,vmcompute,hns -ErrorAction SilentlyContinue |
    Format-Table Name,Status,StartType,DisplayName -AutoSize
Write-Host "vmcompute.exe exists:" (Test-Path "$env:SystemRoot\System32\vmcompute.exe")
Write-Host "hns.exe exists:" (Test-Path "$env:SystemRoot\System32\hns.exe")

Section "Pending Reboot Markers"
Write-Host "CBS RebootPending:" (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending")
Write-Host "WU RebootRequired:" (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired")

Section "Next"
Write-Host "Log saved to: $LogPath"
Write-Host "If VirtualMachinePlatform is enabled and reboot markers are present, reboot once before trying ubuntu2404 again."

Stop-Transcript
