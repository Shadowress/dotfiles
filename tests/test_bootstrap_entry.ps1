Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$TestRoot = Split-Path $PSScriptRoot -Parent
$ProbeRoot = Join-Path ([IO.Path]::GetTempPath()) `
    ("dotfiles-bootstrap-entry.{0}" -f [guid]::NewGuid().ToString('N'))
$TemporaryRoot = [IO.Path]::GetFullPath(
    [IO.Path]::GetTempPath()
).TrimEnd('\')
$OldUserProfile = $env:USERPROFILE

try {
    $repository = Join-Path $ProbeRoot '.dotfiles'
    New-Item -ItemType Directory -Path $repository | Out-Null

    $git = Join-Path $env:ProgramFiles 'Git\cmd\git.exe'
    & $git -c core.excludesFile=/dev/null -C $repository init --quiet
    if ($LASTEXITCODE -ne 0) {
        throw 'Could not initialize the entry-point test repository.'
    }
    & $git -C $repository remote add origin `
        https://github.com/Shadowress/dotfiles.git
    if ($LASTEXITCODE -ne 0) {
        throw 'Could not configure the entry-point test repository.'
    }

    $installer = @'
#!/usr/bin/env bash
printf '[OK] Fixture: installer received <%s>\n' "$1"
'@
    [IO.File]::WriteAllText(
        (Join-Path $repository 'install.sh'),
        $installer,
        [Text.UTF8Encoding]::new($false)
    )

    $env:USERPROFILE = $ProbeRoot
    $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass `
        -File (Join-Path $TestRoot 'bootstrap.ps1') `
        'literal;not-a-command' 2>&1 | Out-String
    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0) {
        throw "The bootstrap entry point failed with exit code $exitCode.`n$output"
    }
    if (-not $output.Contains(
            '[OK] Fixture: installer received <literal;not-a-command>'
        )) {
        throw "The installer argument was not preserved literally.`n$output"
    }
    if (-not $output.Contains('[OK] Bootstrap: Installation completed.')) {
        throw "The bootstrap success status was not printed.`n$output"
    }

    Move-Item -LiteralPath $repository `
        -Destination (Join-Path $ProbeRoot 'valid-repository')
    [IO.File]::WriteAllText($repository, 'not a repository')
    $previousErrorAction = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $failureOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass `
            -File (Join-Path $TestRoot 'bootstrap.ps1') 2>&1 | Out-String
        $failureExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorAction
    }
    if ($failureExitCode -eq 0 -or
        -not $failureOutput.Contains('[ERROR] Dotfiles:')) {
        throw "The bootstrap error status was not reported correctly.`n$failureOutput"
    }

    Write-Host '[OK] Test: Windows bootstrap entry point succeeded'
}
finally {
    $env:USERPROFILE = $OldUserProfile

    $resolvedPath = [IO.Path]::GetFullPath($ProbeRoot)
    $parent = [IO.Path]::GetDirectoryName($resolvedPath).TrimEnd('\')
    $leaf = [IO.Path]::GetFileName($resolvedPath)
    if (-not [StringComparer]::OrdinalIgnoreCase.Equals(
            $parent,
            $TemporaryRoot
        ) -or -not $leaf.StartsWith('dotfiles-bootstrap-entry.')) {
        throw "Refusing to remove unexpected test path: $resolvedPath"
    }

    if (Test-Path -LiteralPath $resolvedPath) {
        Remove-Item -LiteralPath $resolvedPath -Recurse -Force
    }
}
