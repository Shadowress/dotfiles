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

test_command_discovery_uses_path_and_fallback_candidates() (
    local candidate_result
    local discovery_status=0
    local original_path="$PATH"
    local path_result
    local temporary_home
    local unfiltered_result

    temporary_home="$(make_test_directory dotfiles-environment-test)" || return 1
    trap 'remove_test_directory "$temporary_home" dotfiles-environment-test' EXIT
    mkdir -p "$temporary_home/path" "$temporary_home/empty" || return 1
    printf '#!/bin/bash\nprintf "fixture 1.0\\n"\n' \
        > "$temporary_home/path/fixture-command"
    printf '#!/bin/bash\nexit 1\n' > "$temporary_home/unusable"
    printf '#!/bin/bash\nprintf "fixture 1.0\\n"\n' \
        > "$temporary_home/fallback"
    chmod +x "$temporary_home/path/fixture-command" \
        "$temporary_home/unusable" "$temporary_home/fallback" || return 1

    PATH="$temporary_home/path"
    path_result="$(find_executable --filter is_executable_usable \
        "fixture-command" \
        "$temporary_home/fallback")" || discovery_status=1

    PATH="$temporary_home/empty"
    candidate_result="$(find_executable --filter is_executable_usable \
        "fixture-command" \
        "$temporary_home/unusable" "$temporary_home/fallback")" || \
        discovery_status=1
    unfiltered_result="$(find_executable \
        "missing-command" "$temporary_home/unusable")" || \
        discovery_status=1
    PATH="$original_path"
    hash -r

    (( discovery_status == 0 )) &&
        [[ "$path_result" == "$temporary_home/path/fixture-command" ]] &&
        [[ "$candidate_result" == "$temporary_home/fallback" ]] &&
        [[ "$unfiltered_result" == "$temporary_home/unusable" ]]
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

test_stale_link_is_updated() (
    local temporary_home

    temporary_home="$(make_test_directory dotfiles-environment-test)" || return 1
    trap 'remove_test_directory "$temporary_home" dotfiles-environment-test' EXIT
    printf 'source\n' > "$temporary_home/source"
    ln -s "$temporary_home/missing" "$temporary_home/target" || return 1
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
run_test 'command discovery uses PATH and fallback candidates' \
    test_command_discovery_uses_path_and_fallback_candidates
run_test 'an existing correct symlink is idempotent' \
    test_existing_correct_link_is_idempotent
run_test 'a stale symlink is updated to the requested source' \
    test_stale_link_is_updated
run_test 'a conflicting link target is preserved' \
    test_conflicting_target_is_preserved

finish_test_suite 'Installer environment tests'
