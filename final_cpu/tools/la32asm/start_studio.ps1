$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$env:PYTHONPATH = $root
$requirements = Join-Path $root "requirements.txt"
$venv = Join-Path $root ".venv"
$python = Join-Path $venv "Scripts\python.exe"
$uv = Get-Command uv -ErrorAction SilentlyContinue

if (-not $uv) {
    throw "uv was not found. Install uv or add C:\Users\DELL\.local\bin to PATH."
}

if (-not (Test-Path $python)) {
    Write-Host "Creating LA32 Studio Python environment..."
    & $uv.Source venv --python 3.12 $venv
    if ($LASTEXITCODE -ne 0) { throw "Failed to create Python environment." }
}

Write-Host "Checking LA32 Studio dependencies..."
& $uv.Source pip install --python $python -r $requirements
if ($LASTEXITCODE -ne 0) { throw "Failed to install LA32 Studio dependencies." }

$url = "http://127.0.0.1:8765"
Write-Host "Starting LA32 Studio at $url"
$server = Start-Process -FilePath $python `
    -ArgumentList @("-m", "la32asm", "studio") `
    -WorkingDirectory $root -NoNewWindow -PassThru

try {
    $ready = $false
    for ($attempt = 0; $attempt -lt 100; $attempt++) {
        if ($server.HasExited) {
            throw "LA32 Studio exited during startup with code $($server.ExitCode)."
        }
        try {
            $connection = [Net.Sockets.TcpClient]::new()
            $connection.Connect("127.0.0.1", 8765)
            $connection.Dispose()
            $ready = $true
            break
        } catch {
            Start-Sleep -Milliseconds 100
        }
    }
    if (-not $ready) { throw "LA32 Studio did not listen on port 8765 within 10 seconds." }
    Start-Process $url
    Write-Host "LA32 Studio is running. Press Ctrl+C to stop it."
    Wait-Process -Id $server.Id
} finally {
    if ($server -and -not $server.HasExited) {
        Stop-Process -Id $server.Id -Force
    }
}
