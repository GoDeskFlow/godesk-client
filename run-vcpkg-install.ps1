# run-vcpkg-install.ps1 — atomic env setup + vcpkg install for the
# RustDesk Rust core's native dependencies. Called as a single
# background task so all env vars stay scoped to the one PowerShell
# process.
#
# Usage (in foreground for testing):
#   pwsh -NoProfile -ExecutionPolicy Bypass -File run-vcpkg-install.ps1
#
# Or in background via PowerShell tool with run_in_background:true.
#
# Output is tee'd to vcpkg-install.log so progress can be tailed.
[CmdletBinding()]
param(
  [string]$LogFile = "$PSScriptRoot\vcpkg-install.log"
)

$ErrorActionPreference = "Stop"

# 1. CRITICAL env vars — manifest mode silently ignores --triplet on the
#    command line, so VCPKG_DEFAULT_TRIPLET MUST be in the process environment
#    before vcpkg.exe starts. The overlay-ports under res/vcpkg/aom only
#    support x64-windows-static.
$env:VCPKG_ROOT = "$PSScriptRoot\vcpkg"
$env:VCPKG_DEFAULT_TRIPLET = "x64-windows-static"
$env:VCPKG_DEFAULT_HOST_TRIPLET = "x64-windows-static"

# 2. Source MSVC dev environment so cl.exe / link.exe are on PATH.
$vsPath = "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools"
$vcvars = "$vsPath\VC\Auxiliary\Build\vcvars64.bat"
if (-not (Test-Path $vcvars)) {
  throw "vcvars64.bat not found at $vcvars — install VS Build Tools 2022 with C++ workload"
}

# Pull MSVC env into this PowerShell process via cmd shim.
$envFromCmd = & cmd /c "`"$vcvars`" >nul && set"
$envFromCmd | ForEach-Object {
  if ($_ -match '^([^=]+)=(.*)$') {
    [Environment]::SetEnvironmentVariable($matches[1], $matches[2], 'Process')
  }
}

# Re-set our env vars after MSVC sourcing (vcvars overwrites Path; our
# vcpkg vars don't conflict but be defensive).
$env:VCPKG_ROOT = "$PSScriptRoot\vcpkg"
$env:VCPKG_DEFAULT_TRIPLET = "x64-windows-static"
$env:VCPKG_DEFAULT_HOST_TRIPLET = "x64-windows-static"

# 3. Verify
"=== ENV ==="
"VCPKG_ROOT=$env:VCPKG_ROOT"
"VCPKG_DEFAULT_TRIPLET=$env:VCPKG_DEFAULT_TRIPLET"
"cl.exe in PATH: $((Get-Command cl.exe -ErrorAction SilentlyContinue).Source)"
"vcpkg.exe in PATH: $env:VCPKG_ROOT\vcpkg.exe"
""

# 4. Run vcpkg install. Manifest mode reads client/vcpkg.json. Triplet
#    comes from VCPKG_DEFAULT_TRIPLET env var.
"=== STARTING vcpkg install (1-2h cold compile) ==="
Get-Date

Push-Location $PSScriptRoot
try {
  & "$env:VCPKG_ROOT\vcpkg.exe" install 2>&1 | Tee-Object -FilePath $LogFile
  $exit = $LASTEXITCODE
} finally {
  Pop-Location
}

"=== DONE ==="
Get-Date
"vcpkg exit code: $exit"
exit $exit
