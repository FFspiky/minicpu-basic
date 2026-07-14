$ErrorActionPreference = 'Stop'

$Repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$TopFile = Join-Path $Repo 'rtl\soc\soc_lite_lcd_top.v'
$XdcFiles = @(
    (Join-Path $Repo 'run_vivado\constraints\soc_lite_top.xdc'),
    (Join-Path $Repo 'run_vivado\constraints\lcd_touch.xdc')
)

$ports = [System.Collections.Generic.List[string]]::new()
$decl = [regex]'(?m)^[ \t]*(?:input|output|inout)[ \t]+(?:wire|reg)[ \t]+(?:\[(\d+)[ \t]*:[ \t]*(\d+)\][ \t]*)?(\w+)[ \t]*(?:[,;]|\r?$)'
foreach ($match in $decl.Matches((Get-Content -Raw -LiteralPath $TopFile))) {
    $name = $match.Groups[3].Value
    if ($match.Groups[1].Success) {
        $a = [int]$match.Groups[1].Value
        $b = [int]$match.Groups[2].Value
        for ($i = [Math]::Min($a, $b); $i -le [Math]::Max($a, $b); $i++) {
            $ports.Add("$name`[$i`]")
        }
    } else {
        $ports.Add($name)
    }
}

$pinByPort = @{}
$ioPatterns = [System.Collections.Generic.List[string]]::new()
$pinPattern = [regex]'(?m)^\s*set_property\s+PACKAGE_PIN\s+(\S+)\s+\[get_ports\s+(?:\{([^}]+)\}|([^\]]+))\]'
$ioPattern = [regex]'(?m)^\s*set_property\s+IOSTANDARD\s+\S+\s+\[get_ports\s+(?:\{([^}]+)\}|([^\]]+))\]'

foreach ($xdc in $XdcFiles) {
    $text = Get-Content -Raw -LiteralPath $xdc
    foreach ($match in $pinPattern.Matches($text)) {
        $port = if ($match.Groups[2].Success) { $match.Groups[2].Value.Trim() } else { $match.Groups[3].Value.Trim() }
        if ($pinByPort.ContainsKey($port)) { throw "Duplicate PACKAGE_PIN assignment for $port" }
        $pinByPort[$port] = $match.Groups[1].Value
    }
    foreach ($match in $ioPattern.Matches($text)) {
        $list = if ($match.Groups[1].Success) { $match.Groups[1].Value } else { $match.Groups[2].Value }
        foreach ($token in ($list -split '\s+')) {
            if ($token) { $ioPatterns.Add($token.Trim()) }
        }
    }
}

$failures = [System.Collections.Generic.List[string]]::new()
foreach ($port in $ports) {
    if (-not $pinByPort.ContainsKey($port)) { $failures.Add("Missing PACKAGE_PIN: $port") }
    $base = $port -replace '\[\d+\]$', ''
    $hasIoStandard = $ioPatterns.Contains($port) -or $ioPatterns.Contains($base) -or $ioPatterns.Contains("$base`[*`]")
    if (-not $hasIoStandard) { $failures.Add("Missing IOSTANDARD: $port") }
}
foreach ($port in $pinByPort.Keys) {
    if (-not $ports.Contains($port)) { $failures.Add("Stale PACKAGE_PIN port: $port") }
}
foreach ($group in ($pinByPort.GetEnumerator() | Group-Object Value | Where-Object Count -gt 1)) {
    $failures.Add("Duplicate package pin $($group.Name): $(($group.Group.Name) -join ', ')")
}

if ((Get-Content -Raw -LiteralPath $XdcFiles[0]) -match 'CLOCK_DEDICATED_ROUTE\s+BACKBONE') {
    $failures.Add('CLOCK_DEDICATED_ROUTE BACKBONE would reinsert a BUFG ahead of the ZHOLD PLL')
}
$socXdc = Get-Content -Raw -LiteralPath $XdcFiles[0]
if ($socXdc -match '(?m)^\s*if\s*\{') {
    $failures.Add('Vivado 2019.2 does not support Tcl if commands inside XDC files')
}
if ($socXdc -notmatch 'create_generated_clock\s+-name\s+lcd_core_clk') {
    $failures.Add('lcd_core_clk generated-clock constraint is missing')
}
if (-not $ports.Contains('nand_wp_n')) {
    $failures.Add('nand_wp_n top-level port is required for NAND erase/program support')
}

if ($failures.Count) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Host "STATIC_PREFLIGHT_PASS ports=$($ports.Count) package_pins=$($pinByPort.Count)"
