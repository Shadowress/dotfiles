Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$TestRoot = Split-Path $PSScriptRoot -Parent
$BootstrapContent = Get-Content -Raw -LiteralPath `
    (Join-Path $TestRoot 'bootstrap.ps1')
$BootstrapDefinitions = $BootstrapContent -replace `
    '(?s)\r?\ntry \{\r?\n    Invoke-Bootstrap\r?\n\}\r?\ncatch \{.*$', ''
Invoke-Expression $BootstrapDefinitions

$TestsPassed = 0
$TestsFailed = 0
$GitPath = Find-Git
$BashPath = if ($GitPath) { Find-Bash -GitPath $GitPath } else { $null }

function Write-TestResult {
    param([string] $Name, [bool] $Passed)

    if ($Passed) {
        $script:TestsPassed++
        Write-Host "[OK] Test: $Name"
    }
    else {
        $script:TestsFailed++
        Write-Host "[ERROR] Test: $Name" -ForegroundColor Red
    }
}

function Invoke-Test {
    param([string] $Name, [scriptblock] $Test)

    try {
        Write-TestResult -Name $Name -Passed ([bool] (& $Test))
    }
    catch {
        Write-Host "        $($_.Exception.Message)" -ForegroundColor Red
        Write-TestResult -Name $Name -Passed $false
    }
}

function New-TestDirectory {
    $directory = Join-Path ([IO.Path]::GetTempPath()) `
        ("dotfiles-bootstrap-test.{0}" -f [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $directory | Out-Null
    return $directory
}

function Remove-TestDirectory {
    param([string] $Path)

    $resolvedPath = [IO.Path]::GetFullPath($Path).TrimEnd('\')
    $temporaryRoot = [IO.Path]::GetFullPath(
        [IO.Path]::GetTempPath()
    ).TrimEnd('\')
    $parent = [IO.Path]::GetDirectoryName($resolvedPath).TrimEnd('\')
    $leaf = [IO.Path]::GetFileName($resolvedPath)

    if (-not [StringComparer]::OrdinalIgnoreCase.Equals($parent, $temporaryRoot) -or
        -not $leaf.StartsWith('dotfiles-bootstrap-test.')) {
        throw "Refusing to remove unexpected test path: $resolvedPath"
    }

    if (Test-Path -LiteralPath $resolvedPath) {
        Remove-Item -LiteralPath $resolvedPath -Recurse -Force
    }
}

function Invoke-TestGit {
    param([string[]] $Arguments)

    $previousErrorAction = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        & $script:GitPath -c core.hooksPath=/dev/null `
            -c core.excludesFile=/dev/null @Arguments *> $null
        $gitExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorAction
    }
    if ($gitExitCode -ne 0) {
        throw "Git test fixture command failed: $($Arguments -join ' ')"
    }
}

function New-TestRepository {
    param(
        [string] $Path,
        [string] $InstallerBody = 'exit 0'
    )

    New-Item -ItemType Directory -Path $Path -Force | Out-Null
    Invoke-TestGit -Arguments @('-C', $Path, 'init', '--quiet')
    [IO.File]::WriteAllText(
        (Join-Path $Path 'install.sh'),
        "#!/usr/bin/env bash`n$InstallerBody`n",
        [Text.UTF8Encoding]::new($false)
    )
}

Invoke-Test -Name 'PowerShell status output matches installer format' -Test {
    $output = & {
        Write-Status -Level 'INFO' -Component 'Bootstrap' `
            -Message "first`nsecond"
    } 6>&1
    return [string] ($output | Select-Object -First 1) -eq `
        "[INFO] Bootstrap: first`n        second"
}

Invoke-Test -Name 'Git and Git Bash are discovered' -Test {
    return $null -ne $script:GitPath -and
        $null -ne $script:BashPath -and
        (Test-Program -Path $script:GitPath -Arguments @('--version')) -and
        (Test-Program -Path $script:BashPath -Arguments @('--version'))
}

Invoke-Test -Name 'existing repository succeeds and arguments stay literal' -Test {
    $temporaryRoot = New-TestDirectory
    try {
        $script:DotfilesPath = Join-Path $temporaryRoot `
            'home with spaces\.dotfiles'
        $marker = Join-Path $temporaryRoot 'should-not-run'
        New-TestRepository -Path $script:DotfilesPath -InstallerBody `
            'printf "installer argument: <%s>\n" "$1"'
        $script:InstallArguments = @("literal;touch $marker")

        $output = & { Invoke-Bootstrap } 6>&1 | Out-String
        return $output.Contains('[OK] Git:') -and
            $output.Contains('[OK] Dotfiles:') -and
            $output.Contains("installer argument: <literal;touch $marker>") -and
            $output.Contains('[OK] Bootstrap: Installation completed.') -and
            -not (Test-Path -LiteralPath $marker)
    }
    finally {
        Remove-TestDirectory -Path $temporaryRoot
    }
}

Invoke-Test -Name 'Git for Windows installation hands off to the installer' -Test {
    $temporaryRoot = New-TestDirectory
    try {
        $script:DotfilesPath = Join-Path $temporaryRoot '.dotfiles'
        New-TestRepository -Path $script:DotfilesPath
        $script:InstallArguments = @()
        $script:GitWasInstalled = $false

        function Find-Git {
            if ($script:GitWasInstalled) { return $script:GitPath }
            return $null
        }
        function Find-Bash { return $script:BashPath }
        function Install-GitForWindows { $script:GitWasInstalled = $true }

        $output = & { Invoke-Bootstrap } 6>&1 | Out-String
        return $script:GitWasInstalled -and
            $output.Contains('[OK] Bootstrap:')
    }
    finally {
        Remove-TestDirectory -Path $temporaryRoot
    }
}

Invoke-Test -Name 'existing repository remotes are not bootstrap policy' -Test {
    $temporaryRoot = New-TestDirectory
    try {
        $script:DotfilesPath = Join-Path $temporaryRoot '.dotfiles'
        New-TestRepository -Path $script:DotfilesPath
        Invoke-TestGit -Arguments @(
            '-C', $script:DotfilesPath, 'remote', 'add', 'origin',
            'https://example.com/personal-fork/dotfiles.git'
        )
        Get-ValidatedRepository -GitPath $script:GitPath
        return $true
    }
    finally {
        Remove-TestDirectory -Path $temporaryRoot
    }
}

Invoke-Test -Name 'nested repository is rejected' -Test {
    $temporaryRoot = New-TestDirectory
    try {
        $script:DotfilesPath = Join-Path $temporaryRoot '.dotfiles'
        Invoke-TestGit -Arguments @('-C', $temporaryRoot, 'init', '--quiet')
        New-Item -ItemType Directory -Path $script:DotfilesPath | Out-Null

        try {
            Get-ValidatedRepository -GitPath $script:GitPath
            return $false
        }
        catch {
            return $_.Exception.Message.Contains('not the root')
        }
    }
    finally {
        Remove-TestDirectory -Path $temporaryRoot
    }
}

Invoke-Test -Name 'installer failure is reported with its exit code' -Test {
    $temporaryRoot = New-TestDirectory
    try {
        $script:DotfilesPath = Join-Path $temporaryRoot '.dotfiles'
        New-TestRepository -Path $script:DotfilesPath -InstallerBody 'exit 23'
        $script:InstallArguments = @()

        try {
            Invoke-Bootstrap
            return $false
        }
        catch {
            return $_.Exception.Message.Contains('exit code 23')
        }
    }
    finally {
        Remove-TestDirectory -Path $temporaryRoot
    }
}

Invoke-Test -Name 'existing non-directory target is rejected' -Test {
    $temporaryRoot = New-TestDirectory
    try {
        $script:DotfilesPath = Join-Path $temporaryRoot '.dotfiles'
        [IO.File]::WriteAllText($script:DotfilesPath, 'not a repository')
        $script:InstallArguments = @()

        try {
            Invoke-Bootstrap
            return $false
        }
        catch {
            return $_.Exception.Message.Contains('not a directory')
        }
    }
    finally {
        Remove-TestDirectory -Path $temporaryRoot
    }
}

Invoke-Test -Name 'missing installer is rejected' -Test {
    $temporaryRoot = New-TestDirectory
    try {
        $script:DotfilesPath = Join-Path $temporaryRoot '.dotfiles'
        New-TestRepository -Path $script:DotfilesPath
        Remove-Item -LiteralPath (Join-Path $script:DotfilesPath 'install.sh')
        $script:InstallArguments = @()

        try {
            Invoke-Bootstrap
            return $false
        }
        catch {
            return $_.Exception.Message.Contains('missing or is not a file')
        }
    }
    finally {
        Remove-TestDirectory -Path $temporaryRoot
    }
}

Invoke-Test -Name 'missing Git and WinGet path is reported' -Test {
    function Find-Git { return $null }
    function Install-GitForWindows {
        Stop-Bootstrap -Component 'Git' `
            -Message 'WinGet is required to install Git for Windows.'
    }

    try {
        Invoke-Bootstrap
        return $false
    }
    catch {
        return $_.Exception.Message.Contains('WinGet is required')
    }
}

Invoke-Test -Name 'clone succeeds and restores Git environment' -Test {
    $temporaryRoot = New-TestDirectory
    $oldPrompt = $env:GIT_TERMINAL_PROMPT
    $oldSslOverride = $env:GIT_SSL_NO_VERIFY
    try {
        $source = Join-Path $temporaryRoot 'source'
        $remote = Join-Path $temporaryRoot 'remote.git'
        $script:DotfilesPath = Join-Path $temporaryRoot 'clone with spaces'
        New-TestRepository -Path $source
        Invoke-TestGit -Arguments @('-C', $source, 'add', 'install.sh')
        Invoke-TestGit -Arguments @(
            '-C', $source,
            '-c', 'user.name=Bootstrap-Test',
            '-c', 'user.email=bootstrap@example.invalid',
            'commit', '--quiet', '-m', 'initial'
        )
        Invoke-TestGit -Arguments @('clone', '--quiet', '--bare', $source, $remote)

        $env:GIT_TERMINAL_PROMPT = 'original'
        $env:GIT_SSL_NO_VERIFY = 'true'
        $script:RepositoryUrl = $remote
        Invoke-Clone -GitPath $script:GitPath
        $cloneExists = Test-Path -LiteralPath `
            (Join-Path $script:DotfilesPath '.git')
        $promptRestored = $env:GIT_TERMINAL_PROMPT -eq 'original'
        $sslOverrideRestored = $env:GIT_SSL_NO_VERIFY -eq 'true'
        if (-not ($cloneExists -and $promptRestored -and $sslOverrideRestored)) {
            Write-Host "cloneExists=$cloneExists; promptRestored=$promptRestored; sslOverrideRestored=$sslOverrideRestored"
        }
        return $cloneExists -and $promptRestored -and $sslOverrideRestored
    }
    finally {
        [Environment]::SetEnvironmentVariable(
            'GIT_TERMINAL_PROMPT', $oldPrompt, 'Process'
        )
        [Environment]::SetEnvironmentVariable(
            'GIT_SSL_NO_VERIFY', $oldSslOverride, 'Process'
        )
        Remove-TestDirectory -Path $temporaryRoot
    }
}

Invoke-Test -Name 'clone failure is reported' -Test {
    $temporaryRoot = New-TestDirectory
    try {
        $script:RepositoryUrl = Join-Path $temporaryRoot 'missing.git'
        $script:DotfilesPath = Join-Path $temporaryRoot '.dotfiles'

        try {
            Invoke-Clone -GitPath $script:GitPath
            return $false
        }
        catch {
            return $_.Exception.Message.Contains('repository clone failed')
        }
    }
    finally {
        Remove-TestDirectory -Path $temporaryRoot
    }
}

Write-Host ''
Write-Host ("[SUMMARY] Bootstrap PowerShell tests: {0}/{1} succeeded" -f `
        $TestsPassed, ($TestsPassed + $TestsFailed))

if ($TestsFailed -ne 0) {
    exit 1
}
