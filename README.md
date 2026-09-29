# Dotfiles

This repository contains personal dotfiles for configuring and setting up development environments across multiple machines and operating systems.

---

## Installation

### Linux, WSL, and macOS

1. Run the bootstrap script:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Shadowress/dotfiles/main/bootstrap.sh)"
```

***Note:*** On macOS, the bootstrap may ask you to complete the Xcode Command Line Tools installation. Run the same command again after the installation finishes.

### Windows

1. Run the PowerShell bootstrap:

```powershell
$bootstrap = Join-Path $env:TEMP "dotfiles-bootstrap-$([guid]::NewGuid()).ps1"
Invoke-WebRequest https://raw.githubusercontent.com/Shadowress/dotfiles/main/bootstrap.ps1 -OutFile $bootstrap
powershell -NoProfile -ExecutionPolicy Bypass -File $bootstrap
```

***Note:*** WinGet is required when Git for Windows is not already installed.

### Existing clone

To rerun the installer from an existing clone:

```bash
cd ~/.dotfiles
bash install.sh
```

## Bootstrap tests

Run all bootstrap behavior and entry-point tests from one command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests/run.ps1
```

The runner uses the default WSL distribution for the Unix bootstrap tests and
native Windows PowerShell for the Windows bootstrap tests.

Add `-Network` to also clone the public repository into a temporary directory.
The network test validates the clone without running the repository's
`install.sh`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests/run.ps1 -Network
```
