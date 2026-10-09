<#
.SYNOPSIS
    Configure and build Dino Crisis 3 (Release) into build/Release.

.DESCRIPTION
    Needs the lifted sources first (scripts/recompile.ps1). Uses whichever
    Visual Studio generator CMake picks unless -Generator is given, e.g.
    -Generator "Visual Studio 16 2019" for VS 2019 Build Tools.

.PARAMETER Generator
    CMake generator. Default: CMake's own choice.

.PARAMETER Config
    Build configuration. Default: Release.

.PARAMETER AbiCheck
    Build with -DRECOMP_ABI_CHECK=ON into build-abi instead: slower, and it
    names the first function that returns with a bad stack.
#>
param(
    [string]$Generator,
    [string]$Config = 'Release',
    [switch]$AbiCheck
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$build = Join-Path $root ($(if ($AbiCheck) { 'build-abi' } else { 'build' }))

if (-not (Test-Path (Join-Path $root 'src/recomp/gen'))) {
    throw "No lifted sources in src/recomp/gen. Run scripts/recompile.ps1 first."
}

$configure = @('-S', $root, '-B', $build, '-A', 'x64')
if ($Generator) { $configure += @('-G', $Generator) }
if ($AbiCheck)  { $configure += '-DRECOMP_ABI_CHECK=ON' }

# cmake from PATH, else the one bundled with Visual Studio or its Build Tools
# (found through vswhere), which is often the only CMake on a machine.
$cmake = (Get-Command cmake -ErrorAction SilentlyContinue).Source
if (-not $cmake) {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (Test-Path $vswhere) {
        $vs = & $vswhere -latest -products * -property installationPath
        $bundled = Join-Path "$vs" 'Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe'
        if ($vs -and (Test-Path $bundled)) { $cmake = $bundled }
    }
}
if (-not $cmake) { throw "CMake not found: install it, or Visual Studio's C++ CMake tools." }

# Native commands are judged by exit code alone: Windows PowerShell 5.1 turns
# any stderr line (a compiler warning) into an error under 'Stop'.
$ErrorActionPreference = 'Continue'
& $cmake @configure
if ($LASTEXITCODE -ne 0) { throw "cmake configure failed ($LASTEXITCODE)" }
& $cmake --build $build --config $Config -- -m
if ($LASTEXITCODE -ne 0) { throw "cmake build failed ($LASTEXITCODE)" }

Write-Host "Built $build\$Config\dinocrisis3_recomp.exe (and dinocrisis3_recomp_launcher.exe)"
