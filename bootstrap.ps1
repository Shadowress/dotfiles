[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $InstallArguments = @()
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepositoryUrl = 'https://github.com/Shadowress/dotfiles.git'
$DotfilesPath = Join-Path $HOME '.dotfiles'

function Write-Status {
    param(
        [string] $Level,
        [string] $Component,
        [string] $Message = ''
    )

    if ($Message) {
        $indentedMessage = $Message -replace "`r?`n", "`n        "
        Write-Host "[$Level] ${Component}: $indentedMessage"
    }
    else {
        Write-Host "[$Level] $Component"
    }
}

function Stop-Bootstrap {
    param([string] $Component, [string] $Message)

    throw "[ERROR] ${Component}: $Message"
}

function Test-Program {
    param([string] $Path, [string[]] $Arguments)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $false
    }

    try {
        & $Path @Arguments *> $null
        return $LASTEXITCODE -eq 0
    }
    catch {
        return $false
    }
}

function Find-Program {
    param(
        [string] $Name,
        [string[]] $Candidates,
        [string[]] $TestArguments
    )

    $command = Get-Command $Name -CommandType Application `
        -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command) {
        $Candidates += $command.Source
    }

    foreach ($candidate in $Candidates | Select-Object -Unique) {
        if ($candidate -and
            (Test-Program -Path $candidate -Arguments $TestArguments)) {
            return $candidate
        }
    }

    return $null
}

function Find-Git {
    Find-Program -Name 'git.exe' -TestArguments @('--version') -Candidates @(
        "$env:ProgramFiles\Git\cmd\git.exe"
        "$env:LOCALAPPDATA\Programs\Git\cmd\git.exe"
        "$env:LOCALAPPDATA\Microsoft\WinGet\Links\git.exe"
        "${env:ProgramFiles(x86)}\Git\cmd\git.exe"
    )
}

function Find-Bash {
    param([string] $GitPath)

    $gitRoot = Split-Path (Split-Path $GitPath -Parent) -Parent
    Find-Program -Name 'bash.exe' -TestArguments @('--version') -Candidates @(
        "$gitRoot\bin\bash.exe"
        "$env:ProgramFiles\Git\bin\bash.exe"
        "$env:LOCALAPPDATA\Programs\Git\bin\bash.exe"
        "${env:ProgramFiles(x86)}\Git\bin\bash.exe"
    )
}

function Find-WinGet {
    Find-Program -Name 'winget.exe' -TestArguments @('--version') -Candidates @(
        "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe"
    )
}

function Install-GitForWindows {
    $winget = Find-WinGet
    if (-not $winget) {
        Stop-Bootstrap -Component 'Git' `
            -Message 'WinGet is required to install Git for Windows.'
    }

    Write-Status -Level 'INFO' -Component 'Git' `
        -Message 'Installing Git for Windows with WinGet.'
    $previousErrorAction = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        & $winget install --id Git.Git --exact --source winget `
            --accept-package-agreements --accept-source-agreements
        $wingetExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorAction
    }
    if ($wingetExitCode -ne 0) {
        Stop-Bootstrap -Component 'Git' `
            -Message "WinGet failed with exit code $wingetExitCode."
    }
}

function Get-ValidatedRepository {
    param([string] $GitPath)

    if (-not (Test-Path -LiteralPath $DotfilesPath -PathType Container)) {
        Stop-Bootstrap -Component 'Dotfiles' `
            -Message "$DotfilesPath exists but is not a directory."
    }

    $repositoryRoot = & $GitPath -C $DotfilesPath `
        rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -ne 0) {
        Stop-Bootstrap -Component 'Dotfiles' `
            -Message "$DotfilesPath is not a Git repository."
    }

    $item = Get-Item -LiteralPath $DotfilesPath -Force
    $actualPath = [IO.Path]::GetFullPath($item.FullName).TrimEnd('\', '/')
    $rootPath = [IO.Path]::GetFullPath(
        [string] ($repositoryRoot | Select-Object -First 1)
    ).TrimEnd('\', '/')
    if (-not [StringComparer]::OrdinalIgnoreCase.Equals($actualPath, $rootPath)) {
        Stop-Bootstrap -Component 'Dotfiles' `
            -Message "$DotfilesPath is not the root of its Git repository."
    }

    Write-Status -Level 'OK' -Component 'Dotfiles' `
        -Message "Using the existing repository at $DotfilesPath."
}

function Invoke-Clone {
    param([string] $GitPath)

    Write-Status -Level 'INFO' -Component 'Dotfiles' `
        -Message "Cloning into $DotfilesPath."

    $previousPrompt = $env:GIT_TERMINAL_PROMPT
    $previousSslOverride = $env:GIT_SSL_NO_VERIFY
    $previousErrorAction = $ErrorActionPreference
    try {
        $env:GIT_TERMINAL_PROMPT = '0'
        $env:GIT_SSL_NO_VERIFY = 'false'
        $ErrorActionPreference = 'Continue'
        $gitOutput = & $GitPath -c http.sslVerify=true clone --quiet `
            $RepositoryUrl $DotfilesPath 2>&1
        $gitExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorAction
        $env:GIT_TERMINAL_PROMPT = $previousPrompt
        $env:GIT_SSL_NO_VERIFY = $previousSslOverride
    }

    if ($gitExitCode -ne 0) {
        $details = [string]::Join("`n", [string[]] $gitOutput)
        Stop-Bootstrap -Component 'Dotfiles' `
            -Message "The repository clone failed.`n$details"
    }

    Write-Status -Level 'OK' -Component 'Dotfiles' `
        -Message "Cloned into $DotfilesPath."
}

function Invoke-Bootstrap {
    $git = Find-Git
    $bash = if ($git) { Find-Bash -GitPath $git } else { $null }

    if (-not $git -or -not $bash) {
        Install-GitForWindows

        $git = Find-Git
        if (-not $git) {
            Stop-Bootstrap -Component 'Git' `
                -Message 'Git for Windows was installed, but git.exe could not be found.'
        }

        $bash = Find-Bash -GitPath $git
        if (-not $bash) {
            Stop-Bootstrap -Component 'Git' `
                -Message 'Git for Windows was installed, but bash.exe could not be found.'
        }
    }
    Write-Status -Level 'OK' -Component 'Git' `
        -Message 'A usable Git for Windows installation is available.'

    if (Test-Path -LiteralPath $DotfilesPath) {
        Get-ValidatedRepository -GitPath $git
    }
    else {
        Invoke-Clone -GitPath $git
        Get-ValidatedRepository -GitPath $git
    }

    $installScript = Join-Path $DotfilesPath 'install.sh'
    if (-not (Test-Path -LiteralPath $installScript -PathType Leaf)) {
        Stop-Bootstrap -Component 'Installer' `
            -Message "$installScript is missing or is not a file."
    }

    Write-Status -Level 'INFO' -Component 'Installer' `
        -Message "Starting $installScript."
    $previousErrorAction = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        & $bash $installScript @InstallArguments
        $installerExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorAction
    }
    if ($installerExitCode -ne 0) {
        Stop-Bootstrap -Component 'Installer' `
            -Message "The dotfiles installer failed with exit code $installerExitCode."
    }

    Write-Status -Level 'OK' -Component 'Bootstrap' `
        -Message 'Installation completed.'
}

try {
    Invoke-Bootstrap
}
catch {
    if ($_.Exception.Message.StartsWith('[ERROR] ')) {
        throw
    }

    throw "[ERROR] Bootstrap: $($_.Exception.Message)"
}
