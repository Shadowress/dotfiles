#!/usr/bin/env bash

set -uo pipefail

TEST_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$TEST_ROOT/tests/lib/test_helpers.sh"
source "$TEST_ROOT/lib/logging.sh"
source "$TEST_ROOT/lib/core.sh"
source "$TEST_ROOT/lib/arguments.sh"
source "$TEST_ROOT/lib/components.sh"

FIXTURE_CONTEXT="allowed"
FIXTURE_VALIDATOR_VALUE=""
FIXTURE_VALIDATOR_PROVIDED=""

validate_fixture_mode() {
    FIXTURE_VALIDATOR_VALUE="$1"
    FIXTURE_VALIDATOR_PROVIDED="$2"

    if [[ "$2" == "true" && "$FIXTURE_CONTEXT" != "allowed" ]]; then
        ARGUMENT_VALIDATION_ERROR="The fixture context rejected the value."
        return 1
    fi
}

register_fixture_arguments() {
    register_argument "mode" "ARG_MODE" "enum" "auto" \
        "auto|fast|safe" "validate_fixture_mode" \
        "Select a fixture mode." || return 1
    register_argument "feature" "ARG_FEATURE" "boolean" "false" \
        "" "" "Enable a fixture feature." || return 1
    register_argument "retries" "ARG_RETRIES" "integer" "3" \
        "" "" "Set a retry count." || return 1
    register_argument "label" "ARG_LABEL" "string" "default" \
        "" "" "Set a fixture label."
}

command_fails() {
    "$@" &>/dev/null
    [[ $? -ne 0 ]]
}

test_defaults_are_initialized() (
    register_fixture_arguments || return 1
    parse_arguments || return 1

    find_argument "mode" || return 1
    [[ "$ARG_MODE" == "auto" ]] &&
        [[ "$ARG_FEATURE" == "false" ]] &&
        [[ "$ARG_RETRIES" == "3" ]] &&
        [[ "$ARG_LABEL" == "default" ]] &&
        [[ "${ARGUMENT_PROVIDED[$ARGUMENT_INDEX]}" == "false" ]]
)

test_supported_forms_and_types_are_normalized() (
    register_fixture_arguments || return 1
    parse_arguments \
        --mode=fast \
        --feature \
        --retries -2 \
        --label example || return 1

    [[ "$ARG_MODE" == "fast" ]] &&
        [[ "$ARG_FEATURE" == "true" ]] &&
        [[ "$ARG_RETRIES" == "-2" ]] &&
        [[ "$ARG_LABEL" == "example" ]] || return 1

    parse_arguments --feature=off || return 1
    [[ "$ARG_MODE" == "auto" ]] &&
        [[ "$ARG_FEATURE" == "false" ]] &&
        [[ "$ARG_LABEL" == "default" ]]
)

test_invalid_typed_values_are_rejected() (
    register_fixture_arguments || return 1

    command_fails parse_arguments --mode=unknown &&
        command_fails parse_arguments --feature=maybe &&
        command_fails parse_arguments --retries=many
)

test_invalid_argument_shapes_are_rejected() (
    register_fixture_arguments || return 1

    command_fails parse_arguments --unknown=value &&
        command_fails parse_arguments positional &&
        command_fails parse_arguments --mode &&
        command_fails parse_arguments --mode=fast --mode=safe
)

test_validation_callbacks_receive_normalized_context() (
    register_fixture_arguments || return 1
    parse_arguments --mode=safe || return 1
    FIXTURE_CONTEXT="blocked"

    capture_command validate_arguments
    [[ $CAPTURED_STATUS -ne 0 ]] &&
        [[ "$CAPTURED_OUTPUT" == *"fixture context rejected"* ]] || return 1

    FIXTURE_CONTEXT="allowed"
    validate_arguments || return 1
    [[ "$FIXTURE_VALIDATOR_VALUE" == "safe" ]] &&
        [[ "$FIXTURE_VALIDATOR_PROVIDED" == "true" ]]
)

test_validation_callbacks_receive_default_state() (
    register_fixture_arguments || return 1
    parse_arguments || return 1
    validate_arguments || return 1

    [[ "$FIXTURE_VALIDATOR_VALUE" == "auto" ]] &&
        [[ "$FIXTURE_VALIDATOR_PROVIDED" == "false" ]]
)

test_invalid_registrations_are_rejected() (
    register_fixture_arguments || return 1

    command_fails register_argument "mode" "ARG_OTHER" "string" "x" &&
        command_fails register_argument \
            "other" "ARG_MODE" "string" "x" &&
        command_fails register_argument \
            "bad_name" "ARG_BAD_NAME" "string" "x" &&
        command_fails register_argument \
            "bad-type" "ARG_BAD_TYPE" "path" "x" &&
        command_fails register_argument \
            "bad-default" "ARG_BAD_DEFAULT" "integer" "many" &&
        command_fails register_argument \
            "empty-enum" "ARG_EMPTY_ENUM" "enum" "value" ""
)

test_missing_validator_is_rejected() (
    register_argument "mode" "ARG_MODE" "enum" "auto" \
        "auto|fast" "validator_that_does_not_exist" || return 1
    parse_arguments || return 1

    capture_command validate_arguments

    [[ $CAPTURED_STATUS -ne 0 ]] && \
        [[ "$CAPTURED_OUTPUT" == *"was not found"* ]]
)

test_definition_files_are_loaded() (
    local definitions

    definitions="$(make_test_directory dotfiles-arguments-test)" || return 1
    trap 'remove_test_directory "$definitions" dotfiles-arguments-test' EXIT

    printf '%s\n' \
        'register_argument "first" "ARG_FIRST" "string" "one"' \
        > "$definitions/first.sh"
    printf '%s\n' \
        'register_argument "second" "ARG_SECOND" "boolean" "false"' \
        > "$definitions/second.sh"

    source_shell_files "$definitions" "Argument Loader" || return 1
    parse_arguments --first two --second || return 1

    [[ "$ARG_FIRST" == "two" ]] && [[ "$ARG_SECOND" == "true" ]]
)

test_missing_definition_directory_is_rejected() (
    command_fails source_shell_files \
        "/path/that/does/not/exist" "Argument Loader"
)

register_component_arguments() {
    source "$TEST_ROOT/components/arguments/components.sh"
}

use_fixture_component_registry() {
    COMPONENT_NAMES=("base" "extra" "platform-only")
    COMPONENT_DISPLAY_NAMES=("Base" "Extra" "Platform Only")
    COMPONENT_SETUP_FUNCTIONS=(
        "setup_base"
        "setup_extra"
        "setup_platform_only"
    )
    COMPONENT_PLATFORMS=("all" "all" "mac")
    COMPONENT_DEPENDENCIES=("" "" "")
    MINIMAL_COMPONENTS=("base")
    SELECTED_COMPONENTS=()
}

selected_components_are() {
    local component

    [[ ${#SELECTED_COMPONENTS[@]} -eq $# ]] || return 1
    for component in "$@"; do
        component_is_selected "$component" || return 1
    done
}

test_component_selection_modes() (
    PLATFORM="linux"
    use_fixture_component_registry
    register_component_arguments || return 1

    parse_arguments || return 1
    resolve_component_selection || return 1
    selected_components_are base extra || return 1

    parse_arguments --minimal || return 1
    resolve_component_selection || return 1
    selected_components_are base || return 1

    parse_arguments --minimal --include extra || return 1
    resolve_component_selection || return 1
    selected_components_are base extra || return 1

    parse_arguments --minimal --skip base || return 1
    resolve_component_selection || return 1
    selected_components_are || return 1

    parse_arguments --minimal --include extra --skip base || return 1
    resolve_component_selection || return 1
    selected_components_are extra || return 1

    parse_arguments --only extra || return 1
    resolve_component_selection || return 1
    selected_components_are extra || return 1

    parse_arguments --only=base,extra || return 1
    resolve_component_selection || return 1
    selected_components_are base extra || return 1

    parse_arguments --skip extra || return 1
    resolve_component_selection || return 1
    selected_components_are base || return 1

    PLATFORM="mac"
    parse_arguments || return 1
    resolve_component_selection || return 1
    selected_components_are base extra platform-only || return 1

    parse_arguments --only platform-only || return 1
    resolve_component_selection || return 1
    selected_components_are platform-only || return 1

    parse_arguments --minimal --include platform-only || return 1
    resolve_component_selection || return 1
    selected_components_are base platform-only || return 1

    parse_arguments --skip platform-only || return 1
    resolve_component_selection || return 1
    selected_components_are base extra
)

test_invalid_component_selections_are_rejected() (
    PLATFORM="linux"
    use_fixture_component_registry
    register_component_arguments || return 1

    parse_arguments --only extra --minimal || return 1
    command_fails resolve_component_selection || return 1

    parse_arguments --only extra --include base || return 1
    command_fails resolve_component_selection || return 1

    parse_arguments --only extra --skip base || return 1
    command_fails resolve_component_selection || return 1

    parse_arguments --include extra || return 1
    command_fails resolve_component_selection || return 1

    parse_arguments --minimal --include extra --skip extra || return 1
    capture_command resolve_component_selection
    [[ $CAPTURED_STATUS -ne 0 ]] &&
        [[ "$CAPTURED_OUTPUT" == *"both included and skipped"* ]] || return 1

    parse_arguments --only unknown || return 1
    capture_command resolve_component_selection
    [[ $CAPTURED_STATUS -ne 0 ]] &&
        [[ "$CAPTURED_OUTPUT" == *"Unknown component 'unknown'"* ]] || return 1

    parse_arguments --only platform-only || return 1
    capture_command resolve_component_selection
    [[ $CAPTURED_STATUS -ne 0 ]] &&
        [[ "$CAPTURED_OUTPUT" == *"platform-specific"* ]] &&
        [[ "$CAPTURED_OUTPUT" == *"only available on: macOS"* ]] &&
        [[ "$CAPTURED_OUTPUT" == *"current platform: Linux"* ]]
)

test_component_dependencies_must_be_selected() (
    PLATFORM="linux"
    use_fixture_component_registry
    COMPONENT_DEPENDENCIES=("" "base" "")
    register_component_arguments || return 1

    parse_arguments --skip base || return 1
    capture_command resolve_component_selection
    [[ $CAPTURED_STATUS -ne 0 ]] &&
        [[ "$CAPTURED_OUTPUT" == \
            *"Component 'extra' requires component 'base'"* ]] || return 1

    parse_arguments --only extra || return 1
    capture_command resolve_component_selection
    [[ $CAPTURED_STATUS -ne 0 ]] &&
        [[ "$CAPTURED_OUTPUT" == \
            *"Component 'extra' requires component 'base'"* ]]
)

test_help_and_unknown_options() (
    capture_command bash "$TEST_ROOT/install.sh" --help
    [[ $CAPTURED_STATUS -eq 0 ]] || return 1
    for option in --skip --only --minimal --include --help -h; do
        [[ "$CAPTURED_OUTPUT" == *"$option"* ]] || return 1
    done
    [[ "$CAPTURED_OUTPUT" == *"Components:"* ]] &&
        [[ "$CAPTURED_OUTPUT" == *"Minimal Components:"* ]] || return 1

    capture_command bash "$TEST_ROOT/install.sh" -h
    [[ $CAPTURED_STATUS -eq 0 ]] || return 1
    [[ "$CAPTURED_OUTPUT" == *"Usage: bash install.sh"* ]] || return 1

    capture_command bash "$TEST_ROOT/install.sh" --unknown-option
    [[ $CAPTURED_STATUS -ne 0 ]] &&
        [[ "$CAPTURED_OUTPUT" == *"Unknown option"* ]] &&
        [[ "$CAPTURED_OUTPUT" == *"--help"* ]] || return 1

    capture_command bash "$TEST_ROOT/install.sh" -x
    [[ $CAPTURED_STATUS -ne 0 ]] &&
        [[ "$CAPTURED_OUTPUT" == *"Unknown option"* ]] &&
        [[ "$CAPTURED_OUTPUT" == *"--help"* ]]
)

test_setup_runs_only_selected_components() (
    local calls=""

    COMPONENT_NAMES=("first" "second" "platform-only")
    COMPONENT_DISPLAY_NAMES=("First" "Second" "Platform Only")
    COMPONENT_SETUP_FUNCTIONS=(
        "setup_first"
        "setup_second"
        "setup_platform_only"
    )
    COMPONENT_PLATFORMS=("all" "all" "mac")
    COMPONENT_DEPENDENCIES=("" "" "")
    SELECTED_COMPONENTS=("second" "platform-only")
    PLATFORM="linux"

    setup_first() { calls="${calls}first "; }
    setup_second() { calls="${calls}second "; }
    setup_platform_only() { calls="${calls}platform-only "; }

    reset_setup_counts
    setup_components >/dev/null || return 1

    [[ "$calls" == "second " ]] &&
        [[ $SETUP_TOTAL -eq 1 ]] &&
        [[ $SETUP_SUCCEEDED -eq 1 ]]
)

test_failed_dependencies_block_dependent_setups() (
    local calls=""
    local output
    local output_directory
    local output_file

    output_directory="$(make_test_directory dotfiles-dependency-test)" || return 1
    trap 'remove_test_directory "$output_directory" dotfiles-dependency-test' EXIT
    output_file="$output_directory/output"

    COMPONENT_NAMES=("base" "dependent")
    COMPONENT_DISPLAY_NAMES=("Base" "Dependent")
    COMPONENT_SETUP_FUNCTIONS=("setup_base" "setup_dependent")
    COMPONENT_PLATFORMS=("all" "all")
    COMPONENT_DEPENDENCIES=("" "base")
    SELECTED_COMPONENTS=("base" "dependent")
    PLATFORM="linux"

    setup_base() { calls="${calls}base "; return 1; }
    setup_dependent() { calls="${calls}dependent "; }

    reset_setup_counts
    setup_components > "$output_file" || return 1
    output="$(< "$output_file")"

    [[ "$calls" == "base " ]] &&
        [[ $SETUP_TOTAL -eq 2 ]] &&
        [[ $SETUP_FAILED -eq 2 ]] &&
        [[ "$output" == *"Dependency failed: Base"* ]]
)

run_test 'defaults are initialized' test_defaults_are_initialized
run_test 'supported forms and types are normalized' \
    test_supported_forms_and_types_are_normalized
run_test 'invalid typed values are rejected' \
    test_invalid_typed_values_are_rejected
run_test 'invalid argument shapes are rejected' \
    test_invalid_argument_shapes_are_rejected
run_test 'validators receive normalized explicit values' \
    test_validation_callbacks_receive_normalized_context
run_test 'validators receive default state' \
    test_validation_callbacks_receive_default_state
run_test 'invalid registrations are rejected' \
    test_invalid_registrations_are_rejected
run_test 'missing validators are rejected' test_missing_validator_is_rejected
run_test 'definition files are loaded' test_definition_files_are_loaded
run_test 'missing definition directories are rejected' \
    test_missing_definition_directory_is_rejected
run_test 'component selection modes are deterministic' \
    test_component_selection_modes
run_test 'invalid component selections are rejected' \
    test_invalid_component_selections_are_rejected
run_test 'component dependencies must be selected' \
    test_component_dependencies_must_be_selected
run_test 'help and unknown options behave consistently' \
    test_help_and_unknown_options
run_test 'setup runs only selected components' \
    test_setup_runs_only_selected_components
run_test 'failed dependencies block dependent component setups' \
    test_failed_dependencies_block_dependent_setups

finish_test_suite 'Installer argument tests'
