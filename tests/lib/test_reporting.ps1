function Resolve-TestRunnerArguments {
    param([string[]] $Arguments)

    $network = $false
    $reportLevel = 'All'
    $networkProvided = $false
    $reportLevelProvided = $false

    foreach ($argument in $Arguments) {
        switch -Regex ($argument) {
            '^--network$' {
                if ($networkProvided) {
                    throw '[ERROR] Arguments: --network was provided more than once.'
                }
                $network = $true
                $networkProvided = $true
                continue
            }

            '^--report-level=(.*)$' {
                if ($reportLevelProvided) {
                    throw '[ERROR] Arguments: --report-level was provided more than once.'
                }

                $value = $Matches[1]
                $reportLevel = switch ($value) {
                    'all' { 'All' }
                    'results' { 'Results' }
                    'errors' { 'Errors' }
                    default {
                        throw "[ERROR] Arguments: Invalid value for --report-level: '$value'; expected one of: all, results, errors."
                    }
                }
                $reportLevelProvided = $true
                continue
            }

            '^--report-level$' {
                throw '[ERROR] Arguments: --report-level requires a value in the form --report-level=<value>.'
            }

            default {
                throw "[ERROR] Arguments: Unknown argument: $argument."
            }
        }
    }

    return [pscustomobject] @{
        Network = $network
        ReportLevel = $reportLevel
    }
}

function Initialize-TestReporting {
    param(
        [ValidateSet('All', 'Results', 'Errors')]
        [string] $ReportLevel
    )

    $script:TestReportLevel = $ReportLevel
    $script:TotalTestsPassed = 0
    $script:TotalTestsFailed = 0
}

function Test-ReportLineIsVisible {
    param([string] $Line)

    switch ($script:TestReportLevel) {
        'All' {
            return $true
        }
        'Results' {
            return $Line -match '^\[(OK|ERROR)\]'
        }
        'Errors' {
            return $Line -match '^\[ERROR\]'
        }
    }
}

function Write-TestReportLine {
    param([string] $Line)

    if (Test-ReportLineIsVisible -Line $Line) {
        Write-Host $Line
    }
}

function Add-TestReportOutput {
    param([object[]] $Output)

    $failuresBefore = $script:TotalTestsFailed

    foreach ($item in $Output) {
        foreach ($line in ([string] $item -split "`r?`n")) {
            if ($line -match '^\[SUMMARY\]') {
                continue
            }

            if ($line -match '^\[OK\] Test:') {
                $script:TotalTestsPassed++
            }
            elseif ($line -match '^\[ERROR\] Test:') {
                $script:TotalTestsFailed++
            }

            Write-TestReportLine -Line $line
        }
    }

    return $script:TotalTestsFailed -gt $failuresBefore
}

function Invoke-ReportedTestSuite {
    param(
        [string] $Name,
        [scriptblock] $Action
    )

    Write-TestReportLine -Line "[INFO] Suite: Running $Name."

    $output = @()
    $exitCode = 1
    $exceptionMessage = ''
    $previousErrorAction = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(& $Action 2>&1)
        $exitCode = $LASTEXITCODE
    }
    catch {
        $exceptionMessage = $_.Exception.Message
    }
    finally {
        $ErrorActionPreference = $previousErrorAction
    }

    $reportedFailure = Add-TestReportOutput -Output $output
    if ($exitCode -ne 0 -and -not $reportedFailure) {
        $script:TotalTestsFailed++
        $message = if ($exceptionMessage) {
            "$Name could not run: $exceptionMessage"
        }
        else {
            "$Name exited with code $exitCode."
        }
        Write-TestReportLine -Line "[ERROR] Test: $message"
    }
}

function Write-CombinedTestSummary {
    $total = $script:TotalTestsPassed + $script:TotalTestsFailed
    Write-Host ''
    Write-Host ("[SUMMARY] Tests: {0}/{1} succeeded" -f `
            $script:TotalTestsPassed, $total)
}
