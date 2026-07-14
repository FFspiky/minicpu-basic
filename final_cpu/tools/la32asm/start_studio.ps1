param(
    [ValidateRange(1, 65535)]
    [int]$Port = 8765,
    [switch]$NoBrowser,
    [switch]$SmokeTest,
    [switch]$SkipToolchainSetup
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$env:PYTHONPATH = $root
$requirements = Join-Path $root "requirements.txt"
$venv = Join-Path $root ".venv"
$portablePython = Join-Path $root "runtime\python\python.exe"
$python = $null

function Test-Python([string]$Candidate) {
    if (-not (Test-Path -LiteralPath $Candidate -PathType Leaf)) { return $false }
    & $Candidate -c "import sys; assert sys.version_info >= (3, 10)" 2>$null
    return $LASTEXITCODE -eq 0
}

function Convert-ToWslPath([string]$WindowsPath) {
    $resolved = [IO.Path]::GetFullPath($WindowsPath)
    $drive = $resolved.Substring(0, 1).ToLowerInvariant()
    $tail = $resolved.Substring(2).Replace('\', '/')
    return "/mnt/$drive$tail"
}

if (Test-Python $portablePython) {
    $python = $portablePython
    Write-Host "Using bundled Python runtime."
} else {
    $venvPython = Join-Path $venv "Scripts\python.exe"
    if ((Test-Path -LiteralPath $venvPython) -and -not (Test-Python $venvPython)) {
        Write-Warning "The copied .venv is not portable and will be recreated."
        $resolvedVenv = [IO.Path]::GetFullPath($venv)
        if (-not $resolvedVenv.StartsWith([IO.Path]::GetFullPath($root), [StringComparison]::OrdinalIgnoreCase)) {
            throw "Refusing to remove a virtual environment outside the Studio directory."
        }
        Remove-Item -LiteralPath $resolvedVenv -Recurse -Force
    }

    if (-not (Test-Python $venvPython)) {
        $uv = Get-Command uv -ErrorAction SilentlyContinue
        if ($uv) {
            Write-Host "Creating LA32 Studio Python environment with uv..."
            & $uv.Source venv --python 3.12 $venv
        } else {
            $launcher = Get-Command py -ErrorAction SilentlyContinue
            if (-not $launcher) { $launcher = Get-Command python -ErrorAction SilentlyContinue }
            if (-not $launcher) {
                throw "No bundled Python, uv, py, or python was found. Use the portable distribution instead of copying the source tree."
            }
            Write-Host "Creating LA32 Studio Python environment with $($launcher.Source)..."
            & $launcher.Source -m venv $venv
        }
        if ($LASTEXITCODE -ne 0) { throw "Failed to create Python environment." }

        $venvPython = Join-Path $venv "Scripts\python.exe"
        Write-Host "Installing LA32 Studio dependencies..."
        & $venvPython -m pip install -r $requirements
        if ($LASTEXITCODE -ne 0) { throw "Failed to install LA32 Studio dependencies." }
    }
    $python = $venvPython
}

# A portable package carries the Linux-hosted teaching GCC as a tarball.  WSL
# is the only host prerequisite for C compilation; the UI and UART/NAND tools
# remain usable without it.
$toolchainArchive = Join-Path $root "runtime\loongarch32r.tar.gz"
if (-not $SkipToolchainSetup -and -not $env:LA32_GCC -and (Test-Path -LiteralPath $toolchainArchive)) {
    $wsl = Get-Command wsl -ErrorAction SilentlyContinue
    if ($wsl) {
        $linuxRoot = (& $wsl.Source bash -lc 'printf %s "$HOME/.la32studio/loongarch32r"').Trim()
        if ($LASTEXITCODE -eq 0 -and $linuxRoot) {
            $linuxCompiler = "$linuxRoot/bin/loongarch32r-linux-gnusf-gcc"
            & $wsl.Source test -x $linuxCompiler
            if ($LASTEXITCODE -ne 0) {
                Write-Host "Installing bundled LA32R GCC into WSL (first launch only)..."
                $archiveWsl = Convert-ToWslPath $toolchainArchive
                $linuxInstallRoot = $linuxRoot.Substring(0, $linuxRoot.LastIndexOf('/'))
                & $wsl.Source mkdir -p $linuxInstallRoot
                if ($LASTEXITCODE -eq 0) {
                    & $wsl.Source tar -xzf $archiveWsl -C $linuxInstallRoot
                }
                if ($LASTEXITCODE -ne 0) { throw "Failed to unpack the bundled LA32R GCC in WSL." }
            }
            $env:LA32_GCC = $linuxCompiler
            Write-Host "LA32R GCC: $linuxCompiler"
        }
    } else {
        Write-Warning "WSL is unavailable. Studio will open, but C compilation is disabled until WSL is enabled."
    }
}

& $python -c "import fastapi, uvicorn, pydantic, serial" 2>$null
if ($LASTEXITCODE -ne 0) {
    throw "The Python runtime is incomplete. Rebuild the portable distribution."
}

$url = "http://127.0.0.1:$Port"
Write-Host "Starting LA32 Studio at $url"
$server = Start-Process -FilePath $python `
    -ArgumentList @("-m", "la32asm", "studio", "--host", "127.0.0.1", "--port", "$Port") `
    -WorkingDirectory $root -NoNewWindow -PassThru

try {
    $ready = $false
    for ($attempt = 0; $attempt -lt 200; $attempt++) {
        if ($server.HasExited) {
            throw "LA32 Studio exited during startup with code $($server.ExitCode)."
        }
        try {
            $connection = [Net.Sockets.TcpClient]::new()
            $connection.Connect("127.0.0.1", $Port)
            $connection.Dispose()
            $ready = $true
            break
        } catch {
            Start-Sleep -Milliseconds 100
        }
    }
    if (-not $ready) { throw "LA32 Studio did not listen on port $Port within 20 seconds." }
    if ($SmokeTest) {
        Invoke-RestMethod -Uri "$url/api/ports" -Method Get | Out-Null
        Write-Host "LA32 Studio smoke test passed: $url/api/ports"
        return
    }
    if (-not $NoBrowser) { Start-Process $url }
    Write-Host "LA32 Studio is running. Press Ctrl+C to stop it."
    Wait-Process -Id $server.Id
} finally {
    if ($server -and -not $server.HasExited) {
        Stop-Process -Id $server.Id -Force
    }
}
