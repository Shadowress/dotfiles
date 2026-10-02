Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$TestRoot = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'lib\test_helpers.ps1')

$BootstrapDefinitions = Get-TestScriptDefinitions `
    -Path (Join-Path $TestRoot 'bootstrap.ps1') `
    -EntryPointPattern `
        '(?s)\r?\ntry \{\r?\n    Invoke-Bootstrap\r?\n\}\r?\ncatch \{.*$'
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

Invoke-Test -Name 'PowerShell status output matches installer format' -Test {
    $output = & {
        Write-Status -Level 'INFO' -Component 'Bootstrap' `
            -Message "first`nsecond"
    } 6>&1
    return [string] ($output | Select-Object -First 1) -eq `
        "[INFO] Bootstrap: first`n        second"
}

Invoke-Test -Name 'PowerShell user environment is validated' -Test {
    $temporaryRoot = New-TestDirectory
    $previousDotfilesPath = $script:DotfilesPath
    try {
        $script:DotfilesPath = ''
        Initialize-UserEnvironment -HomeDirectory $temporaryRoot
        $validPath = $script:DotfilesPath -eq `
            (Join-Path $temporaryRoot '.dotfiles')

        $invalidHomes = @(
            ''
            'relative\home'
            (Join-Path $temporaryRoot 'missing')
            [IO.Path]::GetPathRoot($temporaryRoot)
        )
        foreach ($invalidHome in $invalidHomes) {
            try {
                Initialize-UserEnvironment -HomeDirectory $invalidHome
                return $false
            }
            catch {
                if (-not $_.Exception.Message.Contains(
                        '[ERROR] Environment:'
                    )) {
                    return $false
                }
            }
        }

        return $validPath
    }
    finally {
        $script:DotfilesPath = $previousDotfilesPath
        Remove-TestDirectory -Path $temporaryRoot
    }
}

Invoke-Test -Name 'Git and Git Bash are discovered' -Test {
    return $null -ne $script:GitPath -and
        $null -ne $script:BashPath -and
        (Test-Program -Path $script:GitPath -Arguments @('--version')) -and
        (Test-Program -Path $script:BashPath -Arguments @('--version'))
}

Invoke-Test -Name 'Windows junction links are idempotent and updateable' -Test {
    $temporaryRoot = New-TestDirectory
    try {
        New-Item -ItemType Directory -Path `
            (Join-Path $temporaryRoot 'source-one') | Out-Null
        New-Item -ItemType Directory -Path `
            (Join-Path $temporaryRoot 'source-two') | Out-Null
        $testScript = Join-Path $PSScriptRoot 'test_windows_link.sh'

        & $script:BashPath $testScript $temporaryRoot $TestRoot
        return $LASTEXITCODE -eq 0
    }
    finally {
        Remove-TestDirectory -Path $temporaryRoot
    }
}

Invoke-Test -Name 'existing repository succeeds and arguments stay literal' -Test {
    $temporaryRoot = New-TestDirectory
    try {
        $script:DotfilesPath = Join-Path $temporaryRoot `
            'home with spaces\.dotfiles'
        $source = Join-Path $temporaryRoot 'source'
        $remote = Join-Path $temporaryRoot 'remote.git'
        $marker = Join-Path $temporaryRoot 'should-not-run'
        New-TestRepository -GitPath $script:GitPath -Path $source `
            -InstallerBody 'exit 91'
        Invoke-TestGit -GitPath $script:GitPath -Arguments @(
            '-C', $source, 'add', 'install.sh'
        )
        Invoke-TestGit -GitPath $script:GitPath -Arguments @(
            '-C', $source,
            '-c', 'user.name=Bootstrap-Test',
            '-c', 'user.email=bootstrap@example.invalid',
            'commit', '--quiet', '-m', 'initial'
        )
        Invoke-TestGit -GitPath $script:GitPath -Arguments @(
            'clone', '--quiet', '--bare', $source, $remote
        )
        Invoke-TestGit -GitPath $script:GitPath -Arguments @(
            'clone', '--quiet', $remote, $script:DotfilesPath
        )
        [IO.File]::WriteAllText(
            (Join-Path $source 'install.sh'),
            "#!/usr/bin/env bash`nprintf `"installer argument: <%s>\n`" `"`$@`"`n",
            [Text.UTF8Encoding]::new($false)
        )
        Invoke-TestGit -GitPath $script:GitPath -Arguments @(
            '-C', $source, 'add', 'install.sh'
        )
        Invoke-TestGit -GitPath $script:GitPath -Arguments @(
            '-C', $source,
            '-c', 'user.name=Bootstrap-Test',
            '-c', 'user.email=bootstrap@example.invalid',
            'commit', '--quiet', '-m', 'update'
        )
        Invoke-TestGit -GitPath $script:GitPath -Arguments @(
            '-C', $source, 'push', '--quiet', $remote, 'HEAD'
        )
        $script:InstallArguments = @(
            '--minimal'
            '--include=first,second'
            "literal;touch $marker"
        )

        $output = & { Invoke-Bootstrap } 6>&1 | Out-String
        return $output.Contains('[OK] Git:') -and
            $output.Contains('[OK] Dotfiles:') -and
            $output.Contains(
                'installer argument: <--minimal>'
            ) -and
            $output.Contains(
                'installer argument: <--include=first,second>'
            ) -and
            $output.Contains(
                "installer argument: <literal;touch $marker>"
            ) -and
            $output.Contains('[OK] Bootstrap: Installation completed.') -and
            -not (Test-Path -LiteralPath $marker)
    }
    finally {
        Remove-TestDirectory -Path $temporaryRoot
    }
}

Invoke-Test -Name 'repository update failure is reported' -Test {
    $temporaryRoot = New-TestDirectory
    try {
        $script:DotfilesPath = Join-Path $temporaryRoot '.dotfiles'
        New-TestRepository -GitPath $script:GitPath `
            -Path $script:DotfilesPath
        $script:InstallArguments = @()

        try {
            Invoke-Bootstrap
            return $false
        }
        catch {
            return $_.Exception.Message.Contains('repository update failed')
        }
    }
    finally {
        Remove-TestDirectory -Path $temporaryRoot
    }
}

Invoke-Test -Name 'Git for Windows installation hands off to the installer' -Test {
    $temporaryRoot = New-TestDirectory
    try {
        $script:DotfilesPath = Join-Path $temporaryRoot '.dotfiles'
        New-TestRepository -GitPath $script:GitPath `
            -Path $script:DotfilesPath
        $script:InstallArguments = @()
        $script:GitWasInstalled = $false

        function Find-Git {
            if ($script:GitWasInstalled) { return $script:GitPath }
            return $null
        }
        function Find-Bash { return $script:BashPath }
        function Install-GitForWindows { $script:GitWasInstalled = $true }
        function Invoke-RepositoryUpdate { }

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
        New-TestRepository -GitPath $script:GitPath `
            -Path $script:DotfilesPath
        Invoke-TestGit -GitPath $script:GitPath -Arguments @(
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
        Invoke-TestGit -GitPath $script:GitPath `
            -Arguments @('-C', $temporaryRoot, 'init', '--quiet')
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
        New-TestRepository -GitPath $script:GitPath `
            -Path $script:DotfilesPath -InstallerBody 'exit 23'
        $script:InstallArguments = @()
        function Invoke-RepositoryUpdate { }

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
        New-TestRepository -GitPath $script:GitPath `
            -Path $script:DotfilesPath
        Remove-Item -LiteralPath (Join-Path $script:DotfilesPath 'install.sh')
        $script:InstallArguments = @()
        function Invoke-RepositoryUpdate { }

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
        New-TestRepository -GitPath $script:GitPath -Path $source
        Invoke-TestGit -GitPath $script:GitPath `
            -Arguments @('-C', $source, 'add', 'install.sh')
        Invoke-TestGit -GitPath $script:GitPath -Arguments @(
            '-C', $source,
            '-c', 'user.name=Bootstrap-Test',
            '-c', 'user.email=bootstrap@example.invalid',
            'commit', '--quiet', '-m', 'initial'
        )
        Invoke-TestGit -GitPath $script:GitPath `
            -Arguments @('clone', '--quiet', '--bare', $source, $remote)

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

Write-TestSummary -Name 'Bootstrap PowerShell tests' `
    -Passed $TestsPassed -Failed $TestsFailed

if ($TestsFailed -ne 0) {
    exit 1
}
