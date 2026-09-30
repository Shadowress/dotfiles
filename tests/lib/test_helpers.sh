TESTS_PASSED=0
TESTS_FAILED=0

pass_test() {
    TESTS_PASSED=$((TESTS_PASSED + 1))
    printf '[OK] Test: %s\n' "$1"
}

fail_test() {
    TESTS_FAILED=$((TESTS_FAILED + 1))
    printf '[ERROR] Test: %s\n' "$1" >&2
}

run_test() {
    if "$2"; then
        pass_test "$1"
    else
        fail_test "$1"
    fi
}

finish_test_suite() {
    if [[ "${DOTFILES_TEST_AGGREGATE:-false}" != "true" ]]; then
        printf '\n[SUMMARY] %s: %s/%s succeeded\n' \
            "$1" "$TESTS_PASSED" "$((TESTS_PASSED + TESTS_FAILED))"
    fi
    (( TESTS_FAILED == 0 ))
}

capture_command() {
    local restore_errexit="false"

    [[ "$-" != *e* ]] || restore_errexit="true"
    set +e
    CAPTURED_OUTPUT="$("$@" 2>&1)"
    CAPTURED_STATUS=$?
    [[ "$restore_errexit" != "true" ]] || set -e
    return 0
}

script_before_line() {
    local script="$1"
    local stop_line="$2"

    awk -v stop_line="$stop_line" \
        '$0 == stop_line { exit } { print }' "$script"
}

make_test_directory() {
    local prefix="${1:-dotfiles-test}"

    [[ "$prefix" =~ ^dotfiles-[a-z0-9-]+$ ]] || {
        printf 'Invalid test-directory prefix: %s\n' "$prefix" >&2
        return 1
    }

    mktemp -d "${TMPDIR:-/tmp}/$prefix.XXXXXX"
}

remove_test_directory() {
    local directory="$1"
    local prefix="${2:-dotfiles-test}"

    case "$directory" in
        "${TMPDIR:-/tmp}/$prefix".*)
            rm -rf -- "$directory"
            ;;

        *)
            printf 'Refusing to remove unexpected test path: %s\n' \
                "$directory" >&2
            return 1
            ;;
    esac
}

create_test_repository() {
    local repository="$1"
    local installer_body="${2:-exit 0}"

    mkdir -p "$repository" || return 1
    GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null \
        git -c core.excludesFile=/dev/null -C "$repository" \
            init --quiet || return 1
    printf '#!/usr/bin/env bash\n%s\n' "$installer_body" \
        > "$repository/install.sh"
}
