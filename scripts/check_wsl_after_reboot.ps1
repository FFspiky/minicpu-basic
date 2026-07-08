$ErrorActionPreference = "Continue"

$LogDir = "D:\CPU_DESIGN\wsl_repair_logs"
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
$Stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$LogPath = Join-Path $LogDir "wsl_after_reboot_$Stamp.log"

Start-Transcript -Path $LogPath -Force

Write-Host "WSL post-reboot check"
Write-Host "Timestamp: $(Get-Date)"
Write-Host ""

Write-Host "Feature states:"
dism.exe /online /get-featureinfo /featurename:VirtualMachinePlatform
dism.exe /online /get-featureinfo /featurename:Microsoft-Windows-Subsystem-Linux
dism.exe /online /get-featureinfo /featurename:HypervisorPlatform

Write-Host ""
Write-Host "WSL status:"
wsl --version
wsl --status
wsl -l -v

Write-Host ""
Write-Host "Backend files and services:"
Write-Host "vmcompute.exe exists:" (Test-Path "$env:SystemRoot\System32\vmcompute.exe")
Write-Host "hns.exe exists:" (Test-Path "$env:SystemRoot\System32\hns.exe")
Get-Service WSLService,LxssManager,vmcompute,hns -ErrorAction SilentlyContinue |
    Format-Table Name,Status,StartType,DisplayName -AutoSize

Write-Host ""
Write-Host "Ubuntu registration test:"
ubuntu2404

Write-Host ""
Write-Host "Log saved to: $LogPath"

Stop-Transcript
