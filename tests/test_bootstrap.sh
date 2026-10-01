#!/usr/bin/env bash

set -uo pipefail

TEST_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$TEST_ROOT/tests/lib/test_helpers.sh"

BOOTSTRAP_DEFINITIONS="$(
    script_before_line "$TEST_ROOT/bootstrap.sh" 'main "$@"'
)"

load_bootstrap() {
    eval "$BOOTSTRAP_DEFINITIONS"
}

test_status_format() (
    local temporary_home
    temporary_home="$(make_test_directory dotfiles-bootstrap-test)" || return 1
    trap 'remove_test_directory "$temporary_home" dotfiles-bootstrap-test' EXIT
    HOME="$temporary_home"
    load_bootstrap

    [[ "$(print_status INFO Bootstrap $'first\nsecond')" == \
        $'[INFO] Bootstrap: first\n        second' ]]
)

test_linux_package_managers() (
    local output
    local temporary_home
    local test_distro

    temporary_home="$(make_test_directory dotfiles-bootstrap-test)" || return 1
    trap 'remove_test_directory "$temporary_home" dotfiles-bootstrap-test' EXIT
    HOME="$temporary_home"
    mkdir "$temporary_home/bin"
    for executable in apt-get dnf pacman; do
        printf '#!/usr/bin/env bash\nexit 0\n' \
            > "$temporary_home/bin/$executable"
        chmod +x "$temporary_home/bin/$executable"
    done
    PATH="$temporary_home/bin:$PATH"
    load_bootstrap

    uname() { printf 'Linux\n'; }
    linux_distribution() { printf '%s\n' "$MOCK_DISTRO"; }
    run_as_root() { printf '%s\n' "$*"; }

    for test_distro in ubuntu debian fedora arch; do
        MOCK_DISTRO="$test_distro"
        output="$(install_git)" || return 1
        case "$test_distro" in
            ubuntu|debian)
                [[ "$output" == *'apt-get update'* ]] || return 1
                [[ "$output" == *'apt-get install -y git'* ]] || return 1
                ;;
            fedora)
                [[ "$output" == *'dnf install -y git'* ]] || return 1
                ;;
            arch)
                [[ "$output" == *'pacman -S --needed git'* ]] || return 1
                ;;
        esac
    done
)

test_mac_requests_command_line_tools() (
    local temporary_home

    temporary_home="$(make_test_directory dotfiles-bootstrap-test)" || return 1
    trap 'remove_test_directory "$temporary_home" dotfiles-bootstrap-test' EXIT
    HOME="$temporary_home"
    mkdir "$temporary_home/bin"
    printf '#!/usr/bin/env bash\nprintf requested > "$REQUEST_MARKER"\n' \
        > "$temporary_home/bin/xcode-select"
    chmod +x "$temporary_home/bin/xcode-select"
    PATH="$temporary_home/bin:$PATH"
    REQUEST_MARKER="$temporary_home/requested"
    export REQUEST_MARKER
    load_bootstrap
    uname() { printf 'Darwin\n'; }

    capture_command install_git

    [[ $CAPTURED_STATUS -ne 0 ]] && [[ -f "$REQUEST_MARKER" ]] &&
        [[ "$CAPTURED_OUTPUT" == *'[ERROR] Git:'* ]]
)

test_existing_repository_and_arguments() (
    local output
    local remote
    local source
    local temporary_home

    temporary_home="$(make_test_directory dotfiles-bootstrap-test)" || return 1
    trap 'remove_test_directory "$temporary_home" dotfiles-bootstrap-test' EXIT
    HOME="$temporary_home"
    source="$temporary_home/source"
    remote="$temporary_home/remote.git"
    create_test_repository "$source" 'exit 91' || return 1
    git -C "$source" add install.sh || return 1
    git -C "$source" -c user.name=Bootstrap-Test \
        -c user.email=bootstrap@example.invalid \
        commit --quiet -m initial || return 1
    git clone --quiet --bare "$source" "$remote" || return 1
    git clone --quiet "$remote" "$HOME/.dotfiles" || return 1
    printf '#!/usr/bin/env bash\nprintf "installer argument: <%%s>\\n" "$@"\n' \
        > "$source/install.sh"
    git -C "$source" add install.sh || return 1
    git -C "$source" -c user.name=Bootstrap-Test \
        -c user.email=bootstrap@example.invalid \
        commit --quiet -m update || return 1
    git -C "$source" push --quiet "$remote" HEAD || return 1
    load_bootstrap
    uname() { printf 'Linux\n'; }
    find_usable_git() {
        GIT_EXECUTABLE="$(type -P git)"
        return 0
    }

    output="$(
        main '--minimal' '--include=first,second' \
            'literal;$(touch should-not-run)'
    )" || return 1
    [[ "$output" == *'[OK] Git:'* ]] &&
        [[ "$output" == *'[OK] Dotfiles:'* ]] &&
        [[ "$output" == *'installer argument: <--minimal>'* ]] &&
        [[ "$output" == *'installer argument: <--include=first,second>'* ]] &&
        [[ "$output" == *'installer argument: <literal;$(touch should-not-run)>'* ]] &&
        [[ "$output" == *'[OK] Bootstrap: Installation completed.'* ]] &&
        [[ ! -e "$temporary_home/should-not-run" ]]
)

test_repository_update_failure_is_reported() (
    local temporary_home

    temporary_home="$(make_test_directory dotfiles-bootstrap-test)" || return 1
    trap 'remove_test_directory "$temporary_home" dotfiles-bootstrap-test' EXIT
    HOME="$temporary_home"
    create_test_repository "$HOME/.dotfiles" || return 1
    load_bootstrap
    uname() { printf 'Linux\n'; }
    find_usable_git() {
        GIT_EXECUTABLE="$(type -P git)"
        return 0
    }

    capture_command main
    [[ $CAPTURED_STATUS -ne 0 && \
        "$CAPTURED_OUTPUT" == *'repository update failed'* ]]
)

test_git_install_then_handoff() (
    local installed_marker
    local output
    local temporary_home

    temporary_home="$(make_test_directory dotfiles-bootstrap-test)" || return 1
    trap 'remove_test_directory "$temporary_home" dotfiles-bootstrap-test' EXIT
    HOME="$temporary_home"
    create_test_repository "$HOME/.dotfiles" || return 1
    load_bootstrap
    update_repository() { :; }
    installed_marker="$temporary_home/git-installed"
    uname() { printf 'Linux\n'; }
    find_usable_git() {
        [[ -f "$installed_marker" ]] || return 1
        GIT_EXECUTABLE="$(type -P git)"
    }
    install_git() { : > "$installed_marker"; }

    output="$(main)" || return 1
    [[ -f "$installed_marker" ]] && [[ "$output" == *'[OK] Bootstrap:'* ]]
)

test_existing_remote_is_not_policy() (
    local temporary_home

    temporary_home="$(make_test_directory dotfiles-bootstrap-test)" || return 1
    trap 'remove_test_directory "$temporary_home" dotfiles-bootstrap-test' EXIT
    HOME="$temporary_home"
    create_test_repository "$HOME/.dotfiles" || return 1
    git -C "$HOME/.dotfiles" remote add origin \
        https://example.com/personal-fork/dotfiles.git || return 1
    load_bootstrap
    GIT_EXECUTABLE="$(type -P git)"

    validate_existing_repository >/dev/null
)

test_nested_repository_is_rejected() (
    local temporary_home

    temporary_home="$(make_test_directory dotfiles-bootstrap-test)" || return 1
    trap 'remove_test_directory "$temporary_home" dotfiles-bootstrap-test' EXIT
    HOME="$temporary_home"
    git -C "$HOME" init --quiet || return 1
    mkdir "$HOME/.dotfiles" || return 1
    load_bootstrap
    GIT_EXECUTABLE="$(type -P git)"

    capture_command validate_existing_repository
    [[ $CAPTURED_STATUS -ne 0 && "$CAPTURED_OUTPUT" == *'not the root'* ]]
)

test_installer_failure_is_reported() (
    local temporary_home

    temporary_home="$(make_test_directory dotfiles-bootstrap-test)" || return 1
    trap 'remove_test_directory "$temporary_home" dotfiles-bootstrap-test' EXIT
    HOME="$temporary_home"
    create_test_repository "$HOME/.dotfiles" 'exit 23' || return 1
    load_bootstrap
    update_repository() { :; }
    uname() { printf 'Linux\n'; }
    find_usable_git() {
        GIT_EXECUTABLE="$(type -P git)"
        return 0
    }

    capture_command main
    [[ $CAPTURED_STATUS -ne 0 && "$CAPTURED_OUTPUT" == *'exit code 23'* ]]
)

test_existing_file_is_rejected() (
    local temporary_home

    temporary_home="$(make_test_directory dotfiles-bootstrap-test)" || return 1
    trap 'remove_test_directory "$temporary_home" dotfiles-bootstrap-test' EXIT
    HOME="$temporary_home"
    printf 'not a repository\n' > "$HOME/.dotfiles"
    load_bootstrap
    update_repository() { :; }
    uname() { printf 'Linux\n'; }
    find_usable_git() {
        GIT_EXECUTABLE="$(type -P git)"
        return 0
    }

    capture_command main
    [[ $CAPTURED_STATUS -ne 0 && "$CAPTURED_OUTPUT" == *'not a directory'* ]]
)

test_missing_installer_is_rejected() (
    local temporary_home

    temporary_home="$(make_test_directory dotfiles-bootstrap-test)" || return 1
    trap 'remove_test_directory "$temporary_home" dotfiles-bootstrap-test' EXIT
    HOME="$temporary_home"
    create_test_repository "$HOME/.dotfiles" || return 1
    rm "$HOME/.dotfiles/install.sh"
    load_bootstrap
    update_repository() { :; }
    uname() { printf 'Linux\n'; }
    find_usable_git() {
        GIT_EXECUTABLE="$(type -P git)"
        return 0
    }

    capture_command main
    [[ $CAPTURED_STATUS -ne 0 && \
        "$CAPTURED_OUTPUT" == *'missing or is not a file'* ]]
)

test_unsupported_os_is_rejected() (
    local temporary_home

    temporary_home="$(make_test_directory dotfiles-bootstrap-test)" || return 1
    trap 'remove_test_directory "$temporary_home" dotfiles-bootstrap-test' EXIT
    HOME="$temporary_home"
    load_bootstrap
    uname() { printf 'MINGW64_NT\n'; }

    capture_command main
    [[ $CAPTURED_STATUS -ne 0 && \
        "$CAPTURED_OUTPUT" == *'Use bootstrap.ps1'* ]]
)

test_clone_contract() (
    local arguments_file
    local environment_file
    local mock_git
    local temporary_home

    temporary_home="$(make_test_directory dotfiles-bootstrap-test)" || return 1
    trap 'remove_test_directory "$temporary_home" dotfiles-bootstrap-test' EXIT
    HOME="$temporary_home"
    load_bootstrap
    arguments_file="$temporary_home/arguments"
    environment_file="$temporary_home/environment"
    mock_git="$temporary_home/git"
    printf '#!/usr/bin/env bash\nprintf "%%s\n" "$*" > "%s"\nprintf "%%s|%%s\n" "$GIT_TERMINAL_PROMPT" "$GIT_SSL_NO_VERIFY" > "%s"\n' \
        "$arguments_file" "$environment_file" > "$mock_git"
    chmod +x "$mock_git"
    GIT_EXECUTABLE="$mock_git"

    clone_repository >/dev/null || return 1
    [[ "$(< "$arguments_file")" == \
        "-c http.sslVerify=true clone --quiet $REPOSITORY_URL $DOTFILES" ]] &&
        [[ "$(< "$environment_file")" == '0|false' ]]
)

test_clone_failure_is_reported() (
    local mock_git
    local temporary_home

    temporary_home="$(make_test_directory dotfiles-bootstrap-test)" || return 1
    trap 'remove_test_directory "$temporary_home" dotfiles-bootstrap-test' EXIT
    HOME="$temporary_home"
    load_bootstrap
    mock_git="$temporary_home/git"
    printf '#!/usr/bin/env bash\nexit 19\n' > "$mock_git"
    chmod +x "$mock_git"
    GIT_EXECUTABLE="$mock_git"

    capture_command clone_repository
    [[ $CAPTURED_STATUS -ne 0 && \
        "$CAPTURED_OUTPUT" == *'repository clone failed'* ]]
)

run_test 'status output matches installer format' test_status_format
run_test 'Linux package-manager commands are correct' test_linux_package_managers
run_test 'macOS requests Xcode Command Line Tools' test_mac_requests_command_line_tools
run_test 'existing repository succeeds and arguments stay literal' \
    test_existing_repository_and_arguments
run_test 'repository update failure is reported' \
    test_repository_update_failure_is_reported
run_test 'Git installation hands off to the installer' test_git_install_then_handoff
run_test 'existing repository remotes are not bootstrap policy' \
    test_existing_remote_is_not_policy
run_test 'nested repository is rejected' test_nested_repository_is_rejected
run_test 'installer failure is reported with its exit code' \
    test_installer_failure_is_reported
run_test 'existing non-directory target is rejected' test_existing_file_is_rejected
run_test 'missing installer is rejected' test_missing_installer_is_rejected
run_test 'unsupported operating systems are rejected' test_unsupported_os_is_rejected
run_test 'clone uses the fixed URL and disables prompts' test_clone_contract
run_test 'clone failure is reported' test_clone_failure_is_reported

finish_test_suite 'Bootstrap shell tests'
