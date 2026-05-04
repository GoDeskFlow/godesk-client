# run-cargo-build.ps1 — atomic env setup + cargo build for the RustDesk
# Rust core. Same env-pattern as run-vcpkg-install.ps1 — sources MSVC
# vcvars64.bat into the PowerShell process and pins VCPKG_ROOT so that
# any vcpkg-rs build.rs scripts find the static libs.
#
# Usage:
#   pwsh -NoProfile -ExecutionPolicy Bypass -File run-cargo-build.ps1
[CmdletBinding()]
param(
  [string]$LogFile = "$PSScriptRoot\cargo-build.log",
  [switch]$Release = $true
)

$ErrorActionPreference = "Stop"

# 1. Vcpkg env so build.rs / vcpkg-rs find the static libs.
$env:VCPKG_ROOT = "$PSScriptRoot\vcpkg"
$env:VCPKG_DEFAULT_TRIPLET = "x64-windows-static"
$env:VCPKG_INSTALLED_DIR = "$PSScriptRoot\vcpkg_installed"
# scrap/build.rs reads VCPKG_INSTALLED_ROOT (different name!) and appends
# the triplet to it: `path = VCPKG_INSTALLED_ROOT; path.push(target)`.
# So this must point at the directory CONTAINING `x64-windows-static/`.
# Without it, scrap probes vcpkg/installed/x64-windows-static which
# doesn't exist in manifest-mode layout (we have vcpkg_installed/...).
$env:VCPKG_INSTALLED_ROOT = "$PSScriptRoot\vcpkg_installed"

# CARGO_VCPKG_ENABLE_STATIC, etc — vcpkg-rs reads VCPKGRS_TRIPLET / VCPKGRS_DYNAMIC.
# For x64-windows-static linkage:
$env:VCPKGRS_TRIPLET = "x64-windows-static"
# Do NOT set VCPKGRS_DYNAMIC — that toggles dynamic linkage.
$env:RUSTFLAGS = "-C target-feature=+crt-static"

# bindgen (used by kcp-sys, etc.) needs libclang.dll. LLVM-19 default
# install path on Windows.
if (Test-Path "C:\Program Files\LLVM\bin\libclang.dll") {
  $env:LIBCLANG_PATH = "C:\Program Files\LLVM\bin"
} elseif (Test-Path "C:\Program Files (x86)\LLVM\bin\libclang.dll") {
  $env:LIBCLANG_PATH = "C:\Program Files (x86)\LLVM\bin"
} else {
  Write-Warning "libclang.dll not found — bindgen build scripts will panic."
}

# Bindgen-based crates (magnum-opus, scrap-yuv, etc.) compile C headers
# through libclang. Without -I pointing at our vcpkg include dir they
# fail with "fatal error: 'opus/opus_multistream.h' file not found".
# Pass the include path via BINDGEN_EXTRA_CLANG_ARGS so EVERY bindgen
# build script picks it up — no per-crate env var hunting.
$vcpkgInclude = "$PSScriptRoot\vcpkg_installed\x64-windows-static\include"
$env:BINDGEN_EXTRA_CLANG_ARGS = "-I`"$vcpkgInclude`""
# Also set the generic CFLAGS so non-bindgen C compilation (cc-rs)
# finds the same headers.
$env:CFLAGS = "/I`"$vcpkgInclude`""
$env:CXXFLAGS = "/I`"$vcpkgInclude`""

# 2. Cargo on PATH.
$env:PATH = "$env:USERPROFILE\.cargo\bin;$env:PATH"

# 3. Source MSVC vcvars64.bat into this PowerShell process.
$vsPath = "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools"
$vcvars = "$vsPath\VC\Auxiliary\Build\vcvars64.bat"
if (-not (Test-Path $vcvars)) {
  throw "vcvars64.bat not found at $vcvars"
}
$envFromCmd = & cmd /c "`"$vcvars`" >nul && set"
$envFromCmd | ForEach-Object {
  if ($_ -match '^([^=]+)=(.*)$') {
    [Environment]::SetEnvironmentVariable($matches[1], $matches[2], 'Process')
  }
}

# Re-set after vcvars (defensive — vcvars rewrites Path).
$env:VCPKG_ROOT = "$PSScriptRoot\vcpkg"
$env:VCPKG_DEFAULT_TRIPLET = "x64-windows-static"
$env:VCPKG_INSTALLED_DIR = "$PSScriptRoot\vcpkg_installed"
# scrap/build.rs reads VCPKG_INSTALLED_ROOT (different name!) and appends
# the triplet to it: `path = VCPKG_INSTALLED_ROOT; path.push(target)`.
# So this must point at the directory CONTAINING `x64-windows-static/`.
# Without it, scrap probes vcpkg/installed/x64-windows-static which
# doesn't exist in manifest-mode layout (we have vcpkg_installed/...).
$env:VCPKG_INSTALLED_ROOT = "$PSScriptRoot\vcpkg_installed"
$env:VCPKGRS_TRIPLET = "x64-windows-static"
$vcpkgLib = "$PSScriptRoot\vcpkg_installed\x64-windows-static\lib"
# rustc needs `-L native=<path>` for `#[link]` attributes that name static
# libs (`#[link(name = "opus", kind = "static")]`). Pair with `LIB` env so
# the MSVC linker also resolves anything coming via `cargo:rustc-link-search`.
$env:RUSTFLAGS = "-C target-feature=+crt-static -L native=$vcpkgLib"
$env:PATH = "$env:USERPROFILE\.cargo\bin;$env:PATH"
if (Test-Path "C:\Program Files\LLVM\bin\libclang.dll") {
  $env:LIBCLANG_PATH = "C:\Program Files\LLVM\bin"
}
$vcpkgInclude = "$PSScriptRoot\vcpkg_installed\x64-windows-static\include"
$env:BINDGEN_EXTRA_CLANG_ARGS = "-I`"$vcpkgInclude`""
$env:CFLAGS = "/I`"$vcpkgInclude`""
$env:CXXFLAGS = "/I`"$vcpkgInclude`""
# MSVC link.exe reads LIB env var for static-library search paths.
# Append (don't overwrite) — vcvars already populated it with MSVC SDK libs.
$env:LIB = "$vcpkgLib;$env:LIB"
# cc-rs and other build helpers honour LIBRARY_PATH on all platforms.
$env:LIBRARY_PATH = "$vcpkgLib;$env:LIBRARY_PATH"

"=== ENV ==="
"VCPKG_ROOT=$env:VCPKG_ROOT"
"VCPKG_DEFAULT_TRIPLET=$env:VCPKG_DEFAULT_TRIPLET"
"VCPKGRS_TRIPLET=$env:VCPKGRS_TRIPLET"
"RUSTFLAGS=$env:RUSTFLAGS"
"LIBCLANG_PATH=$env:LIBCLANG_PATH"
"BINDGEN_EXTRA_CLANG_ARGS=$env:BINDGEN_EXTRA_CLANG_ARGS"
"cargo: $((Get-Command cargo -ErrorAction SilentlyContinue).Source)"
"cl.exe: $((Get-Command cl.exe -ErrorAction SilentlyContinue).Source)"
""

"=== STARTING cargo build --release (30-60 min cold) ==="
Get-Date

Push-Location $PSScriptRoot
try {
  # `--features flutter` is REQUIRED — `mod bridge_generated` in lib.rs is
  # gated on it, and that's what re-exports `store_dart_post_cobject` plus
  # the `wire_*` FFI surface that flutter_rust_bridge needs at runtime.
  # Without it the DLL only ships ~15 exports and Flutter panics on launch
  # with "Failed to lookup symbol 'store_dart_post_cobject'".
  if ($Release) {
    & cargo build --release --features flutter 2>&1 | Tee-Object -FilePath $LogFile
  } else {
    & cargo build --features flutter 2>&1 | Tee-Object -FilePath $LogFile
  }
  $exit = $LASTEXITCODE
} finally {
  Pop-Location
}

"=== DONE ==="
Get-Date
"cargo exit code: $exit"
exit $exit
