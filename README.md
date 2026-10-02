# Dotfiles

This repository contains personal dotfiles for configuring and setting up development environments across multiple machines and operating systems.

---

## Components

| Value | Installs | Availability | Requires | In `--minimal` |
|---|---|---|---|:---:|
| `dotnet` | .NET SDK | All platforms | — | No |
| `gcm` | Git Credential Manager | All platforms | `git` | Yes |
| `git` | Git | All platforms | — | Yes |
| `homebrew` | Homebrew | macOS | — | No |
| `nvim` | Neovim | All platforms | — | No |
| `pyenv` | Python Version Manager | All platforms | — | No |

---

## Installation

| Environment | Entry point | Installer arguments | Notes |
|---|---|---|---|
| **Linux**, **WSL**, **macOS** | `bootstrap.sh` | Add `--` before the options | **macOS** may pause for Xcode Command Line Tools; rerun afterward |
| **Windows** | `bootstrap.ps1` | Append options after the script path | WinGet is required only when Git for Windows is unavailable |
| Existing clone | `install.sh` | Append options to `bash install.sh` | Runs from the checked-out repository |

### Linux, WSL, and macOS

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Shadowress/dotfiles/main/bootstrap.sh)"
```

Example with installer arguments:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Shadowress/dotfiles/main/bootstrap.sh)" -- --minimal
```

### Windows

```powershell
$bootstrap = Join-Path $env:TEMP "dotfiles-bootstrap-$([guid]::NewGuid()).ps1"
Invoke-WebRequest https://raw.githubusercontent.com/Shadowress/dotfiles/main/bootstrap.ps1 -OutFile $bootstrap
powershell -NoProfile -ExecutionPolicy Bypass -File $bootstrap
```

Example with installer arguments:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File $bootstrap --minimal
```

### Existing clone

```bash
cd ~/.dotfiles
bash install.sh
```

### Installer options

<table>
  <thead>
    <tr>
      <th>Component</th>
      <th>Argument</th>
      <th>Value</th>
      <th>What it does</th>
      <th>Availability</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td rowspan="5">Installer</td>
      <th><code>--help</code>, <code>-h</code></th>
      <td><em>No value</em></td>
      <td>Show concise usage, valid components, minimal components, accepted values, and examples, then exit successfully without installing anything. Unknown options fail with a reference to <code>--help</code>.</td>
      <td>All platforms</td>
    </tr>
    <tr>
      <th><code>--include &lt;components&gt;</code></th>
      <td><code>&lt;component&gt;[,&lt;component&gt;...]</code></td>
      <td>Add one or more <a href="#components">components</a> to the minimal selection. Requires <code>--minimal</code> and cannot be combined with <code>--only</code>. A component cannot be both included and skipped.</td>
      <td>All platforms</td>
    </tr>
    <tr>
      <th><code>--minimal</code></th>
      <td><em>No value</em></td>
      <td>Start with the centrally defined minimal selection. Cannot be combined with <code>--only</code>.</td>
      <td>All platforms</td>
    </tr>
    <tr>
      <th><code>--only &lt;components&gt;</code></th>
      <td><code>&lt;component&gt;[,&lt;component&gt;...]</code></td>
      <td>Install only one or more listed <a href="#components">components</a>. Cannot be combined with <code>--minimal</code>, <code>--include</code>, or <code>--skip</code>.</td>
      <td>All platforms</td>
    </tr>
    <tr>
      <th><code>--skip &lt;components&gt;</code></th>
      <td><code>&lt;component&gt;[,&lt;component&gt;...]</code></td>
      <td>Remove one or more listed <a href="#components">components</a> from the default or minimal selection. Cannot be combined with <code>--only</code>. A component cannot be both included and skipped.</td>
      <td>All platforms</td>
    </tr>
    <tr>
      <td rowspan="12">Git Credential Manager (GCM)</td>
      <th rowspan="9"><code>--gcm-credential-store=&lt;value&gt;</code></th>
      <td><code>default</code> <strong>(default)</strong></td>
      <td>Retain the existing backend default: <strong>Linux</strong> uses <code>secretservice</code>, native <strong>WSL</strong> uses <code>cache</code>, <strong>macOS</strong> uses GCM's <code>keychain</code>, and <strong>Windows</strong> GCM (including when called from <strong>WSL</strong>) uses <code>wincredman</code>.</td>
      <td>All platforms</td>
    </tr>
    <tr>
      <td><code>wincredman</code></td>
      <td>Store credentials in <strong>Windows</strong> Credential Manager.</td>
      <td><strong>Windows</strong>, or <strong>WSL</strong> using <strong>Windows</strong> GCM.</td>
    </tr>
    <tr>
      <td><code>dpapi</code></td>
      <td>Store credentials in DPAPI-protected files.</td>
      <td><strong>Windows</strong>, or <strong>WSL</strong> using <strong>Windows</strong> GCM.</td>
    </tr>
    <tr>
      <td><code>keychain</code></td>
      <td>Store credentials in <strong>macOS</strong> Keychain.</td>
      <td><strong>macOS</strong> using native GCM.</td>
    </tr>
    <tr>
      <td><code>secretservice</code></td>
      <td>Store credentials using the freedesktop.org Secret Service.</td>
      <td><strong>Linux</strong>, or <strong>WSL</strong> using native GCM.</td>
    </tr>
    <tr>
      <td><code>gpg</code></td>
      <td>Store credentials in GPG-encrypted, <code>pass</code>-compatible files.</td>
      <td><strong>macOS</strong>, <strong>Linux</strong>, or <strong>WSL</strong> using native GCM.</td>
    </tr>
    <tr>
      <td><code>cache</code></td>
      <td>Keep credentials temporarily in Git's in-memory credential cache.</td>
      <td>All platforms</td>
    </tr>
    <tr>
      <td><code>plaintext</code></td>
      <td>Store credentials in unencrypted files. See the <a href="https://github.com/git-ecosystem/git-credential-manager/blob/main/docs/credstores.md">GCM credential-store documentation</a> before using this insecure option.</td>
      <td>All platforms</td>
    </tr>
    <tr>
      <td><code>none</code></td>
      <td>Disable GCM credential storage.</td>
      <td>All platforms</td>
    </tr>
    <tr>
      <th rowspan="3"><code>--wsl-gcm=&lt;value&gt;</code></th>
      <td><code>auto</code> <strong>(default)</strong></td>
      <td>Prefer <strong>Windows</strong> GCM when found; otherwise use native GCM.</td>
      <td><strong>WSL</strong>.</td>
    </tr>
    <tr>
      <td><code>native</code></td>
      <td>Use GCM installed inside <strong>WSL</strong>.</td>
      <td><strong>WSL</strong>.</td>
    </tr>
    <tr>
      <td><code>windows</code></td>
      <td>Use GCM from Git for <strong>Windows</strong>.</td>
      <td><strong>WSL</strong> with Git for <strong>Windows</strong> GCM installed.</td>
    </tr>
  </tbody>
</table>

---

## Tests

Run all tests from PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests/run.ps1
```

Run all tests from shell:

```bash
bash tests/run.sh
```

### Test options

<table>
  <thead>
    <tr>
      <th>Argument</th>
      <th>Value</th>
      <th>What it does</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <th><code>--network</code></th>
      <td><em>No value</em></td>
      <td>Include tests that require internet access. These tests are excluded by default.</td>
    </tr>
    <tr>
      <th rowspan="3"><code>--report-level=&lt;value&gt;</code></th>
      <td><code>all</code> <strong>(default)</strong></td>
      <td>Show all test output, including <code>INFO</code>, <code>OK</code>, and <code>ERROR</code>.</td>
    </tr>
    <tr>
      <td><code>results</code></td>
      <td>Show only <code>OK</code> and <code>ERROR</code> output.</td>
    </tr>
    <tr>
      <td><code>errors</code></td>
      <td>Show only <code>ERROR</code> output.</td>
    </tr>
  </tbody>
</table>
