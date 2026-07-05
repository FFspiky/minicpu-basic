$ErrorActionPreference = "Continue"

$LogDir = "D:\CPU_DESIGN\wsl_repair_logs"
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
$Stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$LogPath = Join-Path $LogDir "wsl_reset_stop_$Stamp.log"

Start-Transcript -Path $LogPath -Force

Write-Host "Stopping stalled WSL feature reset processes..."
Write-Host "Timestamp: $(Get-Date)"

$ids = @(36180, 38560)
foreach ($id in $ids) {
    $p = Get-Process -Id $id -ErrorAction SilentlyContinue
    if ($p) {
        Write-Host "Stopping PID $id ($($p.ProcessName))"
        Stop-Process -Id $id -Force -ErrorAction Continue
    } else {
        Write-Host "PID $id not found"
    }
}

Start-Sleep -Seconds 3

Write-Host ""
Write-Host "Remaining related processes:"
Get-Process dism,powershell,TiWorker,TrustedInstaller -ErrorAction SilentlyContinue |
    Select-Object ProcessName,Id,StartTime,CPU,MainWindowTitle |
    Format-Table -AutoSize

Write-Host ""
Write-Host "Feature states after stop attempt:"
dism.exe /online /get-featureinfo /featurename:VirtualMachinePlatform
dism.exe /online /get-featureinfo /featurename:Microsoft-Windows-Subsystem-Linux
dism.exe /online /get-featureinfo /featurename:HypervisorPlatform

Write-Host ""
Write-Host "WSL backend files/services:"
Get-Service WSLService,LxssManager,vmcompute,hns -ErrorAction SilentlyContinue |
    Format-Table Name,Status,StartType,DisplayName -AutoSize
Write-Host "vmcompute.exe exists:" (Test-Path "$env:SystemRoot\System32\vmcompute.exe")
Write-Host "hns.exe exists:" (Test-Path "$env:SystemRoot\System32\hns.exe")

Stop-Transcript
