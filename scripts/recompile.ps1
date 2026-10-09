<#
.SYNOPSIS
    Lift Dino Crisis 3 into src/recomp/gen with the xboxrecomp pipeline.

.DESCRIPTION
    Runs external/xboxrecomp/scripts/recompile.py against game/default.xbe,
    using this repository's seed file (config/seeds/43430003.json) and
    writing every stage's output under build/pipeline, so nothing is written
    beside the game files. The generated C lands in src/recomp/gen, which is
    what CMakeLists.txt compiles.

    Seeds are applied by the disassembly stage: after changing the seed file,
    run with -From disasm (not -From lift), or the new seeds are ignored.

.PARAMETER From
    Resume at a stage: parse, disasm, identify or lift. Default: parse.

.PARAMETER Only
    Run a single stage.

.PARAMETER Xbe
    The XBE to lift. Default: game/default.xbe.

.EXAMPLE
    ./scripts/recompile.ps1
    ./scripts/recompile.ps1 -From disasm
#>
param(
    [string]$From,
    [string]$Only,
    [string]$Xbe
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$toolkit = Join-Path $root 'external/xboxrecomp'
if (-not $Xbe) { $Xbe = Join-Path $root 'game/default.xbe' }

if (-not (Test-Path (Join-Path $toolkit 'scripts/recompile.py'))) {
    throw "xboxrecomp not found at $toolkit. Run: git submodule update --init --recursive"
}
if (-not (Test-Path $Xbe)) {
    throw "No XBE at $Xbe. Put your extracted disc in game/ (see README.md)."
}

$work = Join-Path $root 'build/pipeline'
New-Item -ItemType Directory -Force $work | Out-Null

$argv = @(
    (Join-Path $toolkit 'scripts/recompile.py'), $Xbe,
    '--work-dir', $work,
    '--project', $root,
    '--json', (Join-Path $work 'default_analysis.json'),
    '--seeds', (Join-Path $root 'config/seeds/43430003.json')
)
if ($From) { $argv += @('--from', $From) }
if ($Only) { $argv += @('--only', $Only) }

# The pipeline's tools run as modules from the toolkit root. Judged by exit
# code alone: the pipeline prints warnings on stderr, and Windows PowerShell
# 5.1 turns any stderr line into an error under 'Stop'.
Push-Location $toolkit
try {
    $ErrorActionPreference = 'Continue'
    & py -3 @argv
    $code = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    if ($code -ne 0) { throw "recompile.py failed ($code)" }
} finally {
    Pop-Location
}
