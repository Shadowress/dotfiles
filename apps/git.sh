setup_git() {
    run_steps \
        install_git \
        configure_git_environment \
        configure_git_settings
}

install_git() {
    ! is_command_in_path "git" || return 0

    case "$OS" in
        linux|wsl)
            case "$DISTRO" in
                ubuntu|debian)
                    sudo apt-get install -y git
                    ;;

                fedora)
                    sudo dnf install -y git
                    ;;

                arch)
                    sudo pacman -S --needed git
                    ;;

                *)
                    return 1
                    ;;
            esac
            ;;

        windows)
            is_command_in_path "winget.exe" || {
                printf 'WinGet is required to install Git.\n'
                return 1
            }

            winget.exe install --id Git.Git --exact --source winget \
                --accept-package-agreements --accept-source-agreements
            ;;

        mac)
            is_command_in_path "brew" || {
                printf 'Homebrew is required to install Git.\n'
                return 1
            }

            brew install git
            ;;

        *)
            return 1
            ;;
    esac
}

configure_git_environment() {
    local git_executable

    case "$OS" in
        linux|wsl)
            git_executable="$(find_executable \
                "/usr/local/bin/git" \
                "/usr/bin/git")"
            ;;

        windows)
            git_executable="$(find_executable \
                "/usr/bin/git" \
                "/ucrt64/bin/git.exe" \
                "/mingw64/bin/git.exe" \
                "/clangarm64/bin/git.exe" \
                "$WINDOWS_PROGRAM_FILES/Git/cmd/git.exe" \
                "$WINDOWS_PROGRAM_FILES/Git/bin/git.exe" \
                "${WINDOWS_LOCAL_APP_DATA:+$WINDOWS_LOCAL_APP_DATA/Programs/Git/cmd/git.exe}" \
                "${WINDOWS_LOCAL_APP_DATA:+$WINDOWS_LOCAL_APP_DATA/Programs/Git/bin/git.exe}" \
                "${WINDOWS_LOCAL_APP_DATA:+$WINDOWS_LOCAL_APP_DATA/Microsoft/WinGet/Links/git.exe}")"
            ;;

        mac)
            git_executable="$(find_executable \
                "/opt/homebrew/bin/git" \
                "/usr/local/bin/git" \
                "/usr/bin/git")"
            ;;

        *)
            return 1
            ;;
    esac

    [[ -n "$git_executable" ]] || {
        printf 'Git was installed, but its executable could not be found.\n'
        return 1
    }

    prepend_to_path "${git_executable%/*}" || return 1

    is_command_in_path "git" || {
        printf 'Git was installed, but it could not be added to PATH.\n'
        return 1
    }
}

configure_git_settings() {
    local shared_config="$DOTFILES/common/git/.gitconfig"

    if [[ "$OS" == "windows" ]]; then
        shared_config="$(cygpath -m "$shared_config")" || return 1

        touch "$HOME/.gitconfig" "$HOME/.gitconfig.local" || return 1

        git config --file "$HOME/.gitconfig" --get-all include.path |
            grep -Fqx "$shared_config" ||
            git config --file "$HOME/.gitconfig" --add include.path "$shared_config"

        return
    fi

    touch "$DOTFILES/common/git/.gitconfig.local" &&
        link_path "$shared_config" "$HOME/.gitconfig" &&
        link_path "$DOTFILES/common/git/.gitconfig.local" "$HOME/.gitconfig.local"
}
