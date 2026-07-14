param(
    [string]$Destination = "",
    [switch]$SkipToolchain,
    [switch]$CreateArchive,
    [switch]$SkipSmokeTest
)

$ErrorActionPreference = "Stop"
$toolRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$finalCpu = [IO.Path]::GetFullPath((Join-Path $toolRoot "..\.."))
if (-not $Destination) {
    $Destination = Join-Path (Split-Path -Parent $finalCpu) "LA32-Studio-Portable"
}
$destinationRoot = [IO.Path]::GetFullPath($Destination)
if (Test-Path -LiteralPath $destinationRoot) {
    throw "Destination already exists: $destinationRoot"
}

$packageCpu = Join-Path $destinationRoot "final_cpu"
$packageTool = Join-Path $packageCpu "tools\la32asm"
$runtime = Join-Path $packageTool "runtime"
New-Item -ItemType Directory -Path $packageTool, $runtime | Out-Null

function Copy-Tree([string]$Source, [string]$Target, [string[]]$ExcludedDirectories = @()) {
    $sourceRoot = [IO.Path]::GetFullPath($Source)
    Get-ChildItem -LiteralPath $sourceRoot -Recurse -File | ForEach-Object {
        $relative = $_.FullName.Substring($sourceRoot.Length).TrimStart('\')
        $parts = $relative.Split('\')
        if ($parts | Where-Object { $ExcludedDirectories -contains $_ }) { return }
        $targetFile = Join-Path $Target $relative
        $targetDirectory = Split-Path -Parent $targetFile
        if (-not (Test-Path -LiteralPath $targetDirectory)) {
            New-Item -ItemType Directory -Path $targetDirectory | Out-Null
        }
        Copy-Item -LiteralPath $_.FullName -Destination $targetFile
    }
}

Write-Host "Copying LA32 Studio sources..."
Copy-Tree (Join-Path $toolRoot "la32asm") (Join-Path $packageTool "la32asm") @("__pycache__")
Copy-Tree (Join-Path $toolRoot "studio") (Join-Path $packageTool "studio")
Copy-Item -LiteralPath (Join-Path $toolRoot "requirements.txt") -Destination $packageTool
Copy-Item -LiteralPath (Join-Path $toolRoot "start_studio.ps1") -Destination $packageTool
Copy-Item -LiteralPath (Join-Path $toolRoot "start_studio.cmd") -Destination $packageTool
Copy-Item -LiteralPath (Join-Path $toolRoot "PORTABLE_README.md") -Destination $destinationRoot

$repoRoot = Split-Path -Parent $finalCpu
$commit = "unknown"
$sourceDirty = $null
$git = Get-Command git -ErrorAction SilentlyContinue
if ($git) {
    $detectedCommit = (& $git.Source -C $repoRoot rev-parse --verify HEAD 2>$null)
    if ($LASTEXITCODE -eq 0 -and $detectedCommit) { $commit = $detectedCommit.Trim() }
    $trackedChanges = (& $git.Source -C $repoRoot status --porcelain=v1 --untracked-files=no)
    if ($LASTEXITCODE -eq 0) { $sourceDirty = [bool]$trackedChanges }
}
$buildInfo = [ordered]@{
    product = "LA32 Studio Portable"
    source_commit = $commit
    source_dirty = $sourceDirty
    created_utc = [DateTime]::UtcNow.ToString("o")
    includes_toolchain = -not [bool]$SkipToolchain
}
$buildInfo | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $destinationRoot "BUILD_INFO.json") -Encoding UTF8

Write-Host "Copying software projects..."
Copy-Tree (Join-Path $finalCpu "sw\game") (Join-Path $packageCpu "sw\game") @("obj", "build", "__pycache__")
Copy-Tree (Join-Path $finalCpu "sw\generic") (Join-Path $packageCpu "sw\generic") @("build", "__pycache__")
Copy-Tree (Join-Path $finalCpu "sw\selftest") (Join-Path $packageCpu "sw\selftest") @("build", "__pycache__")

$pythonCommand = Get-Command python -ErrorAction SilentlyContinue
$pythonHome = if ($pythonCommand) { Split-Path -Parent $pythonCommand.Source } else { "" }
$uvPython = Join-Path $env:APPDATA "uv\python\cpython-3.12-windows-x86_64-none"
if (Test-Path -LiteralPath (Join-Path $uvPython "python.exe")) { $pythonHome = $uvPython }
if (-not $pythonHome -or -not (Test-Path -LiteralPath (Join-Path $pythonHome "python.exe"))) {
    throw "A complete Python 3.12 installation was not found for packaging."
}

Write-Host "Copying the Python runtime..."
Copy-Tree $pythonHome (Join-Path $runtime "python") @("__pycache__", "site-packages")
$portablePython = Join-Path $runtime "python\python.exe"

$uv = Get-Command uv -ErrorAction SilentlyContinue
if ($uv) {
    Write-Host "Installing pinned Python dependencies into the portable runtime..."
    & $uv.Source pip install --python $portablePython --system --break-system-packages -r (Join-Path $toolRoot "requirements.txt")
} else {
    & $portablePython -m ensurepip
    & $portablePython -m pip install -r (Join-Path $toolRoot "requirements.txt")
}
if ($LASTEXITCODE -ne 0) { throw "Failed to populate the portable Python runtime." }

if (-not $SkipToolchain) {
    $wsl = Get-Command wsl -ErrorAction SilentlyContinue
    if (-not $wsl) { throw "WSL is required once on the packaging computer to archive /opt/loongarch32r." }
    $archive = Join-Path $runtime "loongarch32r.tar.gz"
    $drive = $archive.Substring(0, 1).ToLowerInvariant()
    $archiveWsl = "/mnt/$drive" + $archive.Substring(2).Replace('\', '/')
    Write-Host "Archiving the LA32R GCC toolchain (this may take a minute)..."
    & $wsl.Source bash -lc "tar -C /opt -czf '$archiveWsl' loongarch32r"
    if ($LASTEXITCODE -ne 0) { throw "Failed to archive /opt/loongarch32r." }
}

$rootLauncher = @'
@echo off
setlocal
cd /d "%~dp0final_cpu\tools\la32asm"
call start_studio.cmd %*
'@
[IO.File]::WriteAllText((Join-Path $destinationRoot "LA32-Studio.cmd"), $rootLauncher, [Text.Encoding]::ASCII)

& $portablePython -c "import fastapi, uvicorn, pydantic, serial; import sys; sys.path.insert(0, r'$packageTool'); import la32asm"
if ($LASTEXITCODE -ne 0) { throw "Portable package import verification failed." }

if (-not $SkipSmokeTest) {
    $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
    $listener.Start()
    $smokePort = ([Net.IPEndPoint]$listener.LocalEndpoint).Port
    $listener.Stop()
    Write-Host "Starting the packaged Studio smoke test on port $smokePort..."
    & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File `
        (Join-Path $packageTool "start_studio.ps1") -Port $smokePort -NoBrowser -SmokeTest -SkipToolchainSetup
    if ($LASTEXITCODE -ne 0) { throw "Portable package HTTP smoke test failed." }
}

$size = (Get-ChildItem -LiteralPath $destinationRoot -Recurse -File | Measure-Object Length -Sum).Sum
Write-Host ("Portable package created: {0} ({1:N1} MiB)" -f $destinationRoot, ($size / 1MB))

if ($CreateArchive) {
    $archivePath = "$destinationRoot.zip"
    $checksumPath = "$archivePath.sha256"
    if ((Test-Path -LiteralPath $archivePath) -or (Test-Path -LiteralPath $checksumPath)) {
        throw "Archive or checksum already exists next to the destination: $archivePath"
    }
    Write-Host "Creating GitHub Release archive..."
    Compress-Archive -LiteralPath $destinationRoot -DestinationPath $archivePath -CompressionLevel Optimal
    $hash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
    [IO.File]::WriteAllText($checksumPath, "$hash  $([IO.Path]::GetFileName($archivePath))`r`n", [Text.Encoding]::ASCII)
    Write-Host "Release archive: $archivePath"
    Write-Host "SHA256: $hash"
}
