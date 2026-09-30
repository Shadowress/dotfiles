#!/usr/bin/env bash

set -euo pipefail

TESTS_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNNER="$TESTS_DIRECTORY/run.ps1"

if command -v powershell.exe &>/dev/null; then
    if command -v wslpath &>/dev/null; then
        RUNNER="$(wslpath -w "$RUNNER")"
    elif command -v cygpath &>/dev/null; then
        RUNNER="$(cygpath -w "$RUNNER")"
    fi

    exec powershell.exe -NoProfile -ExecutionPolicy Bypass \
        -File "$RUNNER" "$@"
fi

if command -v pwsh &>/dev/null; then
    exec pwsh -NoProfile -File "$RUNNER" "$@"
fi

printf '[ERROR] Test Runner: PowerShell could not be found.\n' >&2
exit 1
