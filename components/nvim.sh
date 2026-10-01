setup_nvim() {
    run_steps \
        install_nvim \
        configure_nvim_environment \
        configure_nvim_settings
}

install_nvim() {
    ! is_command_in_path "nvim" || return 0

    case "$PLATFORM" in
        linux|wsl)
            case "$DISTRO" in
                ubuntu|debian)
                    sudo apt-get install -y neovim
                    ;;

                fedora)
                    sudo dnf install -y neovim
                    ;;

                arch)
                    sudo pacman -S --needed neovim
                    ;;

                *)
                    return 1
                    ;;
            esac
            ;;

        windows)
            is_command_in_path "winget.exe" || {
                printf 'WinGet is required to install Neovim.\n'
                return 1
            }

            winget.exe install --id Neovim.Neovim --exact --source winget \
                --accept-package-agreements --accept-source-agreements
            ;;

        mac)
            is_command_in_path "brew" || {
                printf 'Homebrew is required to install Neovim.\n'
                return 1
            }

            brew install neovim
            ;;

        *)
            return 1
            ;;
    esac
}

configure_nvim_environment() {
    local nvim_executable

    case "$PLATFORM" in
        linux|wsl)
            nvim_executable="$(find_executable \
                "$HOME/.local/bin/nvim" \
                "/usr/local/bin/nvim" \
                "/usr/bin/nvim" \
                "/opt/nvim/bin/nvim" \
                "/opt/nvim-linux-x86_64/bin/nvim" \
                "/opt/nvim-linux-arm64/bin/nvim" \
                "/snap/bin/nvim")"
            ;;

        windows)
            nvim_executable="$(find_executable \
                "$WINDOWS_PROGRAM_FILES/Neovim/bin/nvim.exe" \
                "$WINDOWS_PROGRAM_FILES/nvim/bin/nvim.exe" \
                "${WINDOWS_LOCAL_APP_DATA:+$WINDOWS_LOCAL_APP_DATA/Programs/Neovim/bin/nvim.exe}" \
                "${WINDOWS_LOCAL_APP_DATA:+$WINDOWS_LOCAL_APP_DATA/Programs/nvim/bin/nvim.exe}" \
                "${WINDOWS_LOCAL_APP_DATA:+$WINDOWS_LOCAL_APP_DATA/Microsoft/WinGet/Links/nvim.exe}")"
            ;;

        mac)
            nvim_executable="$(find_executable \
                "/opt/homebrew/bin/nvim" \
                "/usr/local/bin/nvim" \
                "/opt/local/bin/nvim")"
            ;;

        *)
            return 1
            ;;
    esac

    [[ -n "$nvim_executable" ]] || {
        printf 'Neovim was installed, but its executable could not be found.\n'
        return 1
    }

    prepend_to_path "${nvim_executable%/*}" || return 1

    is_command_in_path "nvim" || {
        printf 'Neovim was installed, but it could not be added to PATH.\n'
        return 1
    }
}

configure_nvim_settings() {
    local nvim_config="$CONFIG/nvim"

    if [[ "$PLATFORM" == "windows" ]]; then
        [[ -n "$WINDOWS_LOCAL_APP_DATA" ]] || return 1
        nvim_config="$WINDOWS_LOCAL_APP_DATA/nvim"
    fi

    mkdir -p "${nvim_config%/*}" &&
        link_path "$DOTFILES/config/nvim" "$nvim_config"
}
