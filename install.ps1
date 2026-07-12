<#
.SYNOPSIS
  DragonCode installer for native Windows PowerShell.

.DESCRIPTION
  Downloads the standalone `dragon` binary from VELLORAAI/dragoncode-public-dist,
  installs it to %USERPROFILE%\.dragoncode\bin, and adds that directory to the
  user PATH. This is the native-Windows counterpart to the POSIX `install` shell
  script (which also works under Git Bash / WSL).

.EXAMPLE
  irm https://raw.githubusercontent.com/VELLORAAI/dragoncode-public-dist/main/install.ps1 | iex

.EXAMPLE
  # Pin a version (env var works with the piped one-liner above):
  $env:DRAGON_VERSION = "1.4.28"; irm https://raw.githubusercontent.com/VELLORAAI/dragoncode-public-dist/main/install.ps1 | iex
#>
[CmdletBinding()]
param(
  [string]$Version = $(if ($env:DRAGON_VERSION) { $env:DRAGON_VERSION } else { $env:VERSION }),
  [switch]$NoModifyPath
)

$ErrorActionPreference = 'Stop'
$Repo = 'VELLORAAI/dragoncode-public-dist'
$InstallDir = Join-Path $HOME '.dragoncode\bin'

function Write-Info($msg) { Write-Host $msg }
function Write-Warn($msg) { Write-Host $msg -ForegroundColor Yellow }
function Fail($msg) { Write-Host $msg -ForegroundColor Red; exit 1 }

# --- target detection ------------------------------------------------------
# We ship windows-x64. On ARM64 Windows the x64 build runs under the built-in
# x64 emulation (Windows 11), so x64 is the correct download for both.
$arch = 'x64'
if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64' -or $env:PROCESSOR_ARCHITEW6432 -eq 'ARM64') {
  Write-Warn "ARM64 Windows detected; installing the x64 build (runs under x64 emulation)."
}
$target = "windows-$arch"

# AVX2 → non-baseline; without it we'd want a -baseline asset. Only warn for now
# (baseline Windows assets are a follow-up); the non-baseline binary still runs
# on any AVX2-capable CPU, i.e. essentially all machines from ~2013 on.
try {
  $avx2 = [System.Runtime.Intrinsics.X86.Avx2]::IsSupported
  if (-not $avx2) { Write-Warn "This CPU lacks AVX2; the standard build may not run. A -baseline build is planned." }
} catch { }

$archive = "dragon-$target.zip"

# --- resolve version + URL -------------------------------------------------
if ([string]::IsNullOrWhiteSpace($Version)) {
  $url = "https://github.com/$Repo/releases/latest/download/$archive"
  try {
    $rel = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest" -Headers @{ 'User-Agent' = 'dragoncode-install' }
    $Version = ($rel.tag_name -replace '^v','')
  } catch { $Version = 'latest' }
} else {
  $Version = $Version -replace '^v',''
  $url = "https://github.com/$Repo/releases/download/v$Version/$archive"
}

Write-Info ""
Write-Info "Installing DragonCode $Version ($target)"

# --- download + extract ----------------------------------------------------
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("dragon_install_" + [System.Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
$zip = Join-Path $tmp $archive
try {
  Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
} catch {
  Fail "Download failed: $url`nCheck that a windows-x64 asset exists for this release: https://github.com/$Repo/releases"
}

Expand-Archive -Path $zip -DestinationPath $tmp -Force
$exe = Join-Path $tmp 'dragon.exe'
if (-not (Test-Path $exe)) { Fail "Archive did not contain dragon.exe" }

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
Copy-Item -Path $exe -Destination (Join-Path $InstallDir 'dragon.exe') -Force
Remove-Item -Recurse -Force $tmp

# --- PATH ------------------------------------------------------------------
if (-not $NoModifyPath) {
  $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
  if (-not $userPath) { $userPath = '' }
  if (($userPath -split ';') -notcontains $InstallDir) {
    [Environment]::SetEnvironmentVariable('Path', ($InstallDir + ';' + $userPath).TrimEnd(';'), 'User')
    Write-Info "Added $InstallDir to your user PATH."
  }
  # Make it usable in the current session too.
  if (($env:Path -split ';') -notcontains $InstallDir) { $env:Path = "$InstallDir;$env:Path" }
}

Write-Info ""
Write-Info "DragonCode is installed. To start:"
Write-Info "  cd <project>"
Write-Info "  dragon"
Write-Info ""
Write-Info "If 'dragon' isn't found, open a new terminal so the PATH change takes effect."
Write-Info "For more information visit https://github.com/$Repo"
