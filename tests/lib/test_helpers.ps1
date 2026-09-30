function New-TestDirectory {
    param(
        [string] $Prefix = 'dotfiles-test'
    )

    if ($Prefix -notmatch '^dotfiles-[a-z0-9-]+$') {
        throw "Invalid test-directory prefix: $Prefix"
    }

    $directory = Join-Path ([IO.Path]::GetTempPath()) `
        ("{0}.{1}" -f $Prefix, [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $directory | Out-Null
    return $directory
}

function Get-TestScriptDefinitions {
    param(
        [string] $Path,
        [string] $EntryPointPattern
    )

    $content = Get-Content -Raw -LiteralPath $Path
    return $content -replace $EntryPointPattern, ''
}

function Write-TestSummary {
    param(
        [string] $Name,
        [int] $Passed,
        [int] $Failed
    )

    if ($env:DOTFILES_TEST_AGGREGATE -ne 'true') {
        Write-Host ''
        Write-Host ("[SUMMARY] ${Name}: {0}/{1} succeeded" -f `
                $Passed, ($Passed + $Failed))
    }
}

function Remove-TestDirectory {
    param(
        [string] $Path,
        [string] $Prefix = 'dotfiles-test'
    )

    if ($Prefix -notmatch '^dotfiles-[a-z0-9-]+$') {
        throw "Invalid test-directory prefix: $Prefix"
    }

    $resolvedPath = [IO.Path]::GetFullPath($Path).TrimEnd('\')
    $temporaryRoot = [IO.Path]::GetFullPath(
        [IO.Path]::GetTempPath()
    ).TrimEnd('\')
    $parent = [IO.Path]::GetDirectoryName($resolvedPath).TrimEnd('\')
    $leaf = [IO.Path]::GetFileName($resolvedPath)

    if (-not [StringComparer]::OrdinalIgnoreCase.Equals($parent, $temporaryRoot) -or
        -not $leaf.StartsWith("$Prefix.")) {
        throw "Refusing to remove unexpected test path: $resolvedPath"
    }

    if (Test-Path -LiteralPath $resolvedPath) {
        Remove-Item -LiteralPath $resolvedPath -Recurse -Force
    }
}

function Invoke-TestGit {
    param(
        [string] $GitPath,
        [string[]] $Arguments
    )

    $previousErrorAction = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        & $GitPath -c core.hooksPath=/dev/null `
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
        [string] $GitPath,
        [string] $Path,
        [string] $InstallerBody = 'exit 0'
    )

    New-Item -ItemType Directory -Path $Path -Force | Out-Null
    Invoke-TestGit -GitPath $GitPath `
        -Arguments @('-C', $Path, 'init', '--quiet')
    [IO.File]::WriteAllText(
        (Join-Path $Path 'install.sh'),
        "#!/usr/bin/env bash`n$InstallerBody`n",
        [Text.UTF8Encoding]::new($false)
    )
}
