#!/usr/bin/env bash

set -euo pipefail

readonly REPOSITORY_URL="https://github.com/Shadowress/dotfiles.git"
readonly DOTFILES="$HOME/.dotfiles"
GIT_EXECUTABLE=""

print_status() {
    local level="$1"
    local component="$2"
    local message="${3:-}"

    if [[ -n "$message" ]]; then
        printf '[%s] %s: %s\n' "$level" "$component" \
            "${message//$'\n'/$'\n        '}"
    else
        printf '[%s] %s\n' "$level" "$component"
    fi
}

fail() {
    print_status "ERROR" "$1" "$2" >&2
    exit 1
}

find_usable_git() {
    GIT_EXECUTABLE="$(type -P git || true)"
    [[ -n "$GIT_EXECUTABLE" ]] && "$GIT_EXECUTABLE" --version &>/dev/null
}

run_as_root() {
    if (( EUID == 0 )); then
        "$@"
    elif command -v sudo &>/dev/null; then
        sudo "$@"
    else
        fail "Git" "sudo is required to install Git."
    fi
}

linux_distribution() {
    local ID=""

    [[ -r /etc/os-release ]] || return 1
    # shellcheck disable=SC1091
    . /etc/os-release
    printf '%s\n' "$ID"
}

install_git() {
    local distro=""

    case "$(uname -s)" in
        Linux*)
            distro="$(linux_distribution)" ||
                fail "Operating System" "Cannot identify this Linux distribution."

            print_status "INFO" "Git" \
                "Installing with the system package manager."
            case "$distro" in
                ubuntu|debian)
                    command -v apt-get &>/dev/null ||
                        fail "Git" "apt-get could not be found."
                    run_as_root apt-get update ||
                        fail "Git" "apt-get update failed."
                    run_as_root apt-get install -y git ||
                        fail "Git" "Git installation with apt-get failed."
                    ;;

                fedora)
                    command -v dnf &>/dev/null ||
                        fail "Git" "dnf could not be found."
                    run_as_root dnf install -y git ||
                        fail "Git" "Git installation with dnf failed."
                    ;;

                arch)
                    command -v pacman &>/dev/null ||
                        fail "Git" "pacman could not be found."
                    run_as_root pacman -S --needed git ||
                        fail "Git" "Git installation with pacman failed."
                    ;;

                *)
                    fail "Operating System" \
                        "Unsupported Linux distribution: ${distro:-unknown}"
                    ;;
            esac
            ;;

        Darwin*)
            command -v xcode-select &>/dev/null ||
                fail "Git" "xcode-select is required to install Git on macOS."

            print_status "INFO" "Git" \
                "Requesting the Xcode Command Line Tools installation."
            xcode-select --install &>/dev/null || :
            fail "Git" \
                "Complete the Xcode Command Line Tools installation, then run the bootstrap again."
            ;;

        *)
            fail "Operating System" \
                "Unsupported operating system. Use bootstrap.ps1 on native Windows."
            ;;
    esac
}

validate_existing_repository() {
    local actual_directory
    local repository_root

    [[ -d "$DOTFILES" ]] ||
        fail "Dotfiles" "$DOTFILES exists but is not a directory."

    repository_root="$(
        "$GIT_EXECUTABLE" -C "$DOTFILES" rev-parse --show-toplevel 2>/dev/null
    )" || fail "Dotfiles" "$DOTFILES is not a Git repository."

    actual_directory="$(cd "$DOTFILES" && pwd -P)" ||
        fail "Dotfiles" "$DOTFILES could not be resolved."
    repository_root="$(cd "$repository_root" && pwd -P)" ||
        fail "Dotfiles" "The repository root could not be resolved."
    [[ "$actual_directory" == "$repository_root" ]] ||
        fail "Dotfiles" "$DOTFILES is not the root of its Git repository."

    print_status "OK" "Dotfiles" \
        "Using the existing repository at $DOTFILES."
}

clone_repository() {
    print_status "INFO" "Dotfiles" "Cloning into $DOTFILES."

    GIT_SSL_NO_VERIFY=false GIT_TERMINAL_PROMPT=0 \
        "$GIT_EXECUTABLE" -c http.sslVerify=true \
        clone --quiet "$REPOSITORY_URL" "$DOTFILES" ||
        fail "Dotfiles" "The repository clone failed."

    print_status "OK" "Dotfiles" "Cloned into $DOTFILES."
}

main() {
    local installer_exit_code
    local -a install_arguments=("$@")

    case "$(uname -s)" in
        Linux*|Darwin*) ;;
        *)
            fail "Operating System" \
                "Unsupported operating system. Use bootstrap.ps1 on native Windows."
            ;;
    esac

    if ! find_usable_git; then
        install_git
        find_usable_git || fail "Git" "Git was installed but cannot be executed."
    fi
    print_status "OK" "Git" "A usable Git installation is available."

    if [[ -e "$DOTFILES" || -L "$DOTFILES" ]]; then
        validate_existing_repository
    else
        clone_repository
        validate_existing_repository
    fi

    [[ -f "$DOTFILES/install.sh" ]] ||
        fail "Installer" "$DOTFILES/install.sh is missing or is not a file."

    print_status "INFO" "Installer" "Starting $DOTFILES/install.sh."
    if "$BASH" "$DOTFILES/install.sh" "${install_arguments[@]}"; then
        print_status "OK" "Bootstrap" "Installation completed."
        return 0
    else
        installer_exit_code=$?
    fi

    fail "Installer" \
        "The dotfiles installer failed with exit code $installer_exit_code."
}

main "$@"
