# DragonCode

The Dragon terminal agent — `dragon`. A coding agent that defaults to **Dragon Turbo**,
auto-indexes your repo for whole-codebase retrieval, and compacts context early.

## Install

### macOS (Apple Silicon **or** Intel) and Linux

```sh
curl -fsSL https://raw.githubusercontent.com/VELLORAAI/dragoncode-public-dist/main/install | bash
```

Or with [Homebrew](https://brew.sh):

```sh
brew install velloraai/tap/dragon
```

### Windows

Native PowerShell:

```powershell
irm https://raw.githubusercontent.com/VELLORAAI/dragoncode-public-dist/main/install.ps1 | iex
```

Or, if you use **Git Bash** / **MSYS**, the same `curl … | bash` one-liner above works.
**WSL** users should use the Linux one-liner inside their WSL shell.

### Then

**Open a new terminal** (so `dragon` is on your PATH — on Unix you can instead `source ~/.zshrc`), and run it with no arguments:

```sh
dragon            # paste your MWS API key when prompted → done
```

Binaries for macOS (arm64/x64), Linux (x64/arm64), and Windows (x64) are published on this repo's [Releases](https://github.com/VELLORAAI/dragoncode-public-dist/releases). To pin a version: `… | bash -s -- --version 1.4.28` (Unix) or `$env:DRAGON_VERSION="1.4.28"; irm … | iex` (Windows).
