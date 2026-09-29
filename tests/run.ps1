[CmdletBinding()]
param(
    [switch] $Network
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepositoryRoot = Split-Path $PSScriptRoot -Parent
$TestsPassed = 0
$TestsFailed = 0

function Invoke-TestSuite {
    param(
        [string] $Name,
        [scriptblock] $Action
    )

    Write-Host "[INFO] Test: Running $Name."
    try {
        & $Action
        if ($LASTEXITCODE -ne 0) {
            throw "$Name exited with code $LASTEXITCODE."
        }
        $script:TestsPassed++
        Write-Host "[OK] Test: $Name passed."
    }
    catch {
        $script:TestsFailed++
        Write-Host "[ERROR] Test: $($_.Exception.Message)" `
            -ForegroundColor Red
    }
}

$Wsl = (Get-Command wsl.exe -CommandType Application |
        Select-Object -First 1).Source
$powershell = (Get-Command powershell.exe -CommandType Application |
        Select-Object -First 1).Source
$shellBehavior = 'tests/test_bootstrap.sh'
$shellEntry = 'tests/test_bootstrap_entry.sh'
$powerShellBehavior = Join-Path $PSScriptRoot 'test_bootstrap.ps1'
$powerShellEntry = Join-Path $PSScriptRoot 'test_bootstrap_entry.ps1'

Push-Location $RepositoryRoot
try {
    Invoke-TestSuite -Name 'shell bootstrap behavior' -Action {
        & $Wsl --cd $RepositoryRoot -- bash $shellBehavior
    }
    Invoke-TestSuite -Name 'shell bootstrap entry point' -Action {
        & $Wsl --cd $RepositoryRoot -- bash $shellEntry
    }
    Invoke-TestSuite -Name 'PowerShell bootstrap behavior' -Action {
        & $powershell -NoProfile -ExecutionPolicy Bypass `
            -File $powerShellBehavior
    }
    Invoke-TestSuite -Name 'PowerShell bootstrap entry point' -Action {
        & $powershell -NoProfile -ExecutionPolicy Bypass `
            -File $powerShellEntry
    }

    if ($Network) {
        $networkTest = 'tests/test_bootstrap_clone.sh'
        Invoke-TestSuite -Name 'HTTPS clone integration' -Action {
            & $Wsl --cd $RepositoryRoot -- bash $networkTest
        }
    }
}
finally {
    Pop-Location
}

Write-Host ''
Write-Host ("[SUMMARY] Bootstrap test suites: {0}/{1} succeeded" -f `
        $TestsPassed, ($TestsPassed + $TestsFailed))

if ($TestsFailed -ne 0) {
    exit 1
}
