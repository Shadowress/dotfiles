#!/usr/bin/env bash

set -euo pipefail

TEST_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$TEST_ROOT/tests/lib/test_helpers.sh"

PROBE_DIRECTORY="$(make_test_directory dotfiles-bootstrap-entry)"
trap 'remove_test_directory "$PROBE_DIRECTORY" dotfiles-bootstrap-entry' EXIT

repository="$PROBE_DIRECTORY/.dotfiles"
create_test_repository "$repository" \
    'printf '\''[OK] Fixture: installer received <%s>\n'\'' "$@"'
GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null \
    git -C "$repository" remote add origin \
    https://github.com/Shadowress/dotfiles.git

output="$(
    HOME="$PROBE_DIRECTORY" bash "$TEST_ROOT/bootstrap.sh" \
        '--minimal' '--include=nvim,dotnet'
)"

[[ "$output" == *'[OK] Fixture: installer received <--minimal>'* ]]
[[ "$output" == *'[OK] Fixture: installer received <--include=nvim,dotnet>'* ]]
[[ "$output" == *'[OK] Bootstrap: Installation completed.'* ]]

remote_output="$(
    HOME="$PROBE_DIRECTORY" bash -c "$(< "$TEST_ROOT/bootstrap.sh")" -- \
        '--minimal' '--include=nvim'
)"
[[ "$remote_output" == \
    *'[OK] Fixture: installer received <--minimal>'* ]]
[[ "$remote_output" == \
    *'[OK] Fixture: installer received <--include=nvim>'* ]]

mv "$repository" "$PROBE_DIRECTORY/valid-repository"
printf 'not a repository\n' > "$repository"
capture_command env HOME="$PROBE_DIRECTORY" \
    bash "$TEST_ROOT/bootstrap.sh"

[[ $CAPTURED_STATUS -ne 0 ]]
[[ "$CAPTURED_OUTPUT" == *'[ERROR] Dotfiles:'* ]]

printf '[OK] Test: Bootstrap shell entry point succeeded\n'
