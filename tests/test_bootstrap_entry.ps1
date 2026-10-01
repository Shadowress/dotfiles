Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$TestRoot = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'lib\test_helpers.ps1')

$BootstrapDefinitions = Get-TestScriptDefinitions `
    -Path (Join-Path $TestRoot 'bootstrap.ps1') `
    -EntryPointPattern `
        '(?s)\r?\ntry \{\r?\n    Invoke-Bootstrap\r?\n\}\r?\ncatch \{.*$'
Invoke-Expression $BootstrapDefinitions

$git = Find-Git
if (-not $git) {
    throw 'The entry-point test requires an existing Git for Windows installation.'
}
$bash = Find-Bash -GitPath $git
if (-not $bash) {
    throw 'The entry-point test requires an existing Git Bash installation.'
}

$ProbeRoot = New-TestDirectory -Prefix 'dotfiles-bootstrap-entry'
$OldUserProfile = $env:USERPROFILE

try {
    $repository = Join-Path $ProbeRoot '.dotfiles'
    New-TestRepository -GitPath $git -Path $repository -InstallerBody `
        'printf ''[OK] Fixture: installer received <%s>\n'' "$@"'
    Invoke-TestGit -GitPath $git -Arguments @(
        '-C', $repository, 'remote', 'add', 'origin',
        'https://github.com/Shadowress/dotfiles.git'
    )

    $env:USERPROFILE = $ProbeRoot
    $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass `
        -File (Join-Path $TestRoot 'bootstrap.ps1') `
        '--minimal' '--include=first,second' 2>&1 | Out-String
    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0) {
        throw "The bootstrap entry point failed with exit code $exitCode.`n$output"
    }
    if (-not $output.Contains(
            '[OK] Fixture: installer received <--minimal>'
        ) -or -not $output.Contains(
            '[OK] Fixture: installer received <--include=first,second>'
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
    Remove-TestDirectory -Path $ProbeRoot `
        -Prefix 'dotfiles-bootstrap-entry'
}
