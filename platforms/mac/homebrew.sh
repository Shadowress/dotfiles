setup_homebrew() {
    run_steps \
        install_homebrew \
        configure_homebrew_environment
}

install_homebrew() {
    local installer

    ! is_command_in_path "brew" || return 0

    is_command_in_path "curl" || {
        printf 'curl is required to download Homebrew.\n'
        return 1
    }

    installer="$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
        printf 'Failed to download the Homebrew installer.\n'
        return 1
    }

    /bin/bash -c "$installer" || {
        printf 'Homebrew installation failed.\n'
        return 1
    }
}

configure_homebrew_environment() {
    local brew_executable
    local shell_environment

    brew_executable="$(find_executable \
        "/opt/homebrew/bin/brew" \
        "/usr/local/bin/brew")" || {
        printf 'Homebrew is installed, but its executable could not be found.\n'
        return 1
    }

    shell_environment="$("$brew_executable" shellenv bash)" || return 1
    eval "$shell_environment" || return 1

    is_command_in_path "brew" || {
        printf 'Homebrew was installed, but it could not be added to PATH.\n'
        return 1
    }
}
