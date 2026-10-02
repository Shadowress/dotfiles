#!/usr/bin/env bash

set -euo pipefail

TEST_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$TEST_ROOT/tests/lib/test_helpers.sh"

PROBE_DIRECTORY="$(make_test_directory dotfiles-bootstrap-entry)"
trap 'remove_test_directory "$PROBE_DIRECTORY" dotfiles-bootstrap-entry' EXIT

source_repository="$PROBE_DIRECTORY/source"
remote_repository="$PROBE_DIRECTORY/remote.git"
repository="$PROBE_DIRECTORY/.dotfiles"
create_test_repository "$source_repository" 'exit 91'
GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null \
    git -C "$source_repository" add install.sh
GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null \
    git -C "$source_repository" -c user.name=Bootstrap-Test \
        -c user.email=bootstrap@example.invalid \
        commit --quiet -m initial
GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null \
    git clone --quiet --bare "$source_repository" "$remote_repository"
GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null \
    git clone --quiet "$remote_repository" "$repository"
create_test_repository "$source_repository" \
    'printf '\''[OK] Fixture: installer received <%s>\n'\'' "$@"'
GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null \
    git -C "$source_repository" add install.sh
GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null \
    git -C "$source_repository" -c user.name=Bootstrap-Test \
        -c user.email=bootstrap@example.invalid \
        commit --quiet -m update
GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null \
    git -C "$source_repository" push --quiet "$remote_repository" HEAD

output="$(
    HOME="$PROBE_DIRECTORY" bash "$TEST_ROOT/bootstrap.sh" \
        '--minimal' '--include=first,second'
)"

[[ "$output" == *'[OK] Fixture: installer received <--minimal>'* ]]
[[ "$output" == *'[OK] Fixture: installer received <--include=first,second>'* ]]
[[ "$output" == *'[OK] Bootstrap: Installation completed.'* ]]

remote_output="$(
    HOME="$PROBE_DIRECTORY" bash -c "$(< "$TEST_ROOT/bootstrap.sh")" -- \
        '--minimal' '--include=first'
)"
[[ "$remote_output" == \
    *'[OK] Fixture: installer received <--minimal>'* ]]
[[ "$remote_output" == \
    *'[OK] Fixture: installer received <--include=first>'* ]]

mv "$repository" "$PROBE_DIRECTORY/valid-repository"
printf 'not a repository\n' > "$repository"
capture_command env HOME="$PROBE_DIRECTORY" \
    bash "$TEST_ROOT/bootstrap.sh"

[[ $CAPTURED_STATUS -ne 0 ]]
[[ "$CAPTURED_OUTPUT" == *'[ERROR] Dotfiles:'* ]]

capture_command env HOME= bash "$TEST_ROOT/bootstrap.sh"
[[ $CAPTURED_STATUS -ne 0 ]]
[[ "$CAPTURED_OUTPUT" == *'[ERROR] Environment: HOME is empty'* ]]

capture_command env HOME=/ bash "$TEST_ROOT/bootstrap.sh"
[[ $CAPTURED_STATUS -ne 0 ]]
[[ "$CAPTURED_OUTPUT" == *'[ERROR] Environment: HOME cannot resolve'* ]]

capture_command env HOME=/tmp/.. bash "$TEST_ROOT/bootstrap.sh"
[[ $CAPTURED_STATUS -ne 0 ]]
[[ "$CAPTURED_OUTPUT" == *'[ERROR] Environment: HOME cannot resolve'* ]]

printf '[OK] Test: Bootstrap shell entry point succeeded\n'
