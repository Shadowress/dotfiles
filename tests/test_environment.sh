#!/usr/bin/env bash

set -uo pipefail

TEST_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$TEST_ROOT/tests/lib/test_helpers.sh"
source "$TEST_ROOT/lib/logging.sh"
source "$TEST_ROOT/lib/environment.sh"

test_valid_home_initializes_config() (
    local temporary_home

    temporary_home="$(make_test_directory dotfiles-environment-test)" || return 1
    trap 'remove_test_directory "$temporary_home" dotfiles-environment-test' EXIT
    HOME="$temporary_home"
    CONFIG=""

    initialize_user_environment || return 1
    [[ "$CONFIG" == "$temporary_home/.config" ]]
)

test_unsafe_home_values_are_rejected() (
    local missing_home="/path/that/does/not/exist"

    HOME=""
    capture_command initialize_user_environment
    [[ $CAPTURED_STATUS -ne 0 ]] &&
        [[ "$CAPTURED_OUTPUT" == *"HOME is empty"* ]] || return 1

    HOME="/"
    capture_command initialize_user_environment
    [[ $CAPTURED_STATUS -ne 0 ]] &&
        [[ "$CAPTURED_OUTPUT" == *"filesystem root"* ]] || return 1

    HOME="/tmp/.."
    capture_command initialize_user_environment
    [[ $CAPTURED_STATUS -ne 0 ]] &&
        [[ "$CAPTURED_OUTPUT" == *"filesystem root"* ]] || return 1

    HOME="relative/home"
    capture_command initialize_user_environment
    [[ $CAPTURED_STATUS -ne 0 ]] &&
        [[ "$CAPTURED_OUTPUT" == *"absolute path"* ]] || return 1

    HOME="$missing_home"
    capture_command initialize_user_environment
    [[ $CAPTURED_STATUS -ne 0 ]] &&
        [[ "$CAPTURED_OUTPUT" == *"not an existing directory"* ]]
)

test_existing_correct_link_is_idempotent() (
    local temporary_home

    temporary_home="$(make_test_directory dotfiles-environment-test)" || return 1
    trap 'remove_test_directory "$temporary_home" dotfiles-environment-test' EXIT
    printf 'source\n' > "$temporary_home/source"
    ln -s "$temporary_home/source" "$temporary_home/target" || return 1
    PLATFORM="linux"

    link_path "$temporary_home/source" "$temporary_home/target" || return 1
    [[ "$temporary_home/source" -ef "$temporary_home/target" ]]
)

test_conflicting_target_is_preserved() (
    local temporary_home

    temporary_home="$(make_test_directory dotfiles-environment-test)" || return 1
    trap 'remove_test_directory "$temporary_home" dotfiles-environment-test' EXIT
    printf 'source\n' > "$temporary_home/source"
    printf 'keep me\n' > "$temporary_home/target"
    PLATFORM="linux"

    capture_command link_path "$temporary_home/source" "$temporary_home/target"
    [[ $CAPTURED_STATUS -ne 0 ]] &&
        [[ "$CAPTURED_OUTPUT" == *"Refusing to replace existing path"* ]] &&
        [[ "$(< "$temporary_home/target")" == "keep me" ]]
)

run_test 'valid HOME initializes the configuration directory' \
    test_valid_home_initializes_config
run_test 'unsafe HOME values are rejected' test_unsafe_home_values_are_rejected
run_test 'an existing correct symlink is idempotent' \
    test_existing_correct_link_is_idempotent
run_test 'a conflicting link target is preserved' \
    test_conflicting_target_is_preserved

finish_test_suite 'Installer environment tests'
