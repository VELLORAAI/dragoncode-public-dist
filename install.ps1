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

# Place dragon.exe. On Windows you cannot overwrite a running image, so a plain
# Copy-Item -Force fails whenever Dragon is updating itself (or any dragon is
# open) with "the process cannot access the file because it is being used by
# another process". Windows DOES allow renaming a running exe, so move the old
# one aside first, then copy the new one into place. The stale .old is unlocked
# once that process exits; sweep it best-effort now and again next run.
$dest = Join-Path $InstallDir 'dragon.exe'
$old = Join-Path $InstallDir 'dragon.exe.old'
if (Test-Path $old) { try { Remove-Item -Force $old -ErrorAction Stop } catch { } }
if (Test-Path $dest) {
  try { Rename-Item -Path $dest -NewName 'dragon.exe.old' -Force -ErrorAction Stop }
  catch {
    # Rename can still fail if a prior .old is itself pinned; fall back to the
    # in-place copy so a first-time or not-running install is never blocked.
  }
}
Copy-Item -Path $exe -Destination $dest -Force
Remove-Item -Recurse -Force $tmp

# --- PATH ------------------------------------------------------------------
# Known trade-off: SetEnvironmentVariable rewrites the User value as REG_SZ,
# so pre-existing REG_EXPAND_SZ entries (e.g. %USERPROFILE%\bin) stop
# expanding. We only ever prepend one literal path.
if (-not $NoModifyPath) {
  $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
  if (-not $userPath) { $userPath = '' }
  if (($userPath -split ';') -notcontains $InstallDir) {
    [Environment]::SetEnvironmentVariable('Path', ($InstallDir + ';' + $userPath).TrimEnd(';'), 'User')
    Write-Info "Added $InstallDir to your user PATH."

    # Broadcast WM_SETTINGCHANGE so already-running shells (Explorer, Windows
    # Terminal) hand the new PATH to processes they spawn; without this, only
    # terminals started after a fresh login see the entry. Best effort.
    try {
      $sig = '[DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)] public static extern System.IntPtr SendMessageTimeout(System.IntPtr hWnd, uint Msg, System.UIntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out System.UIntPtr lpdwResult);'
      $smto = Add-Type -MemberDefinition $sig -Name 'SendMessageTimeout' -Namespace 'DragonInstall' -PassThru
      [System.UIntPtr]$broadcastResult = [System.UIntPtr]::Zero
      # 0xffff = HWND_BROADCAST, 0x001A = WM_SETTINGCHANGE, 2 = SMTO_ABORTIFHUNG
      $null = $smto::SendMessageTimeout([System.IntPtr]0xffff, 0x001A, [System.UIntPtr]::Zero, 'Environment', 2, 5000, [ref]$broadcastResult)
    } catch {
      # Non-fatal: a brand-new terminal still picks the PATH up.
    }
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
