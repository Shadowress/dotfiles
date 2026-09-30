[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $Arguments
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepositoryRoot = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'lib\test_reporting.ps1')

try {
    $options = Resolve-TestRunnerArguments -Arguments $Arguments
}
catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 2
}

Initialize-TestReporting -ReportLevel $options.ReportLevel

$Wsl = (Get-Command wsl.exe -CommandType Application |
        Select-Object -First 1).Source
$powershell = (Get-Command powershell.exe -CommandType Application |
        Select-Object -First 1).Source
$shellBehavior = 'tests/test_bootstrap.sh'
$shellEntry = 'tests/test_bootstrap_entry.sh'
$installerArguments = 'tests/test_install_arguments.sh'
$powerShellBehavior = Join-Path $PSScriptRoot 'test_bootstrap.ps1'
$powerShellEntry = Join-Path $PSScriptRoot 'test_bootstrap_entry.ps1'
$previousAggregate = $env:DOTFILES_TEST_AGGREGATE

$env:DOTFILES_TEST_AGGREGATE = 'true'
Push-Location $RepositoryRoot
try {
    Invoke-ReportedTestSuite -Name 'shell bootstrap behavior' -Action {
        & $Wsl --cd $RepositoryRoot -- `
            env DOTFILES_TEST_AGGREGATE=true bash $shellBehavior
    }
    Invoke-ReportedTestSuite -Name 'shell bootstrap entry point' -Action {
        & $Wsl --cd $RepositoryRoot -- `
            env DOTFILES_TEST_AGGREGATE=true bash $shellEntry
    }
    Invoke-ReportedTestSuite -Name 'installer argument behavior' -Action {
        & $Wsl --cd $RepositoryRoot -- `
            env DOTFILES_TEST_AGGREGATE=true bash $installerArguments
    }
    Invoke-ReportedTestSuite -Name 'PowerShell bootstrap behavior' -Action {
        & $powershell -NoProfile -ExecutionPolicy Bypass `
            -File $powerShellBehavior
    }
    Invoke-ReportedTestSuite -Name 'PowerShell bootstrap entry point' -Action {
        & $powershell -NoProfile -ExecutionPolicy Bypass `
            -File $powerShellEntry
    }

    if ($options.Network) {
        $networkTest = 'tests/test_bootstrap_clone.sh'
        Invoke-ReportedTestSuite -Name 'HTTPS clone integration' -Action {
            & $Wsl --cd $RepositoryRoot -- `
                env DOTFILES_TEST_AGGREGATE=true bash $networkTest
        }
    }
}
finally {
    Pop-Location
    [Environment]::SetEnvironmentVariable(
        'DOTFILES_TEST_AGGREGATE', $previousAggregate, 'Process'
    )
}

Write-CombinedTestSummary

if ($script:TotalTestsFailed -ne 0) {
    exit 1
}
