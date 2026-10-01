readonly DOTNET_LTS_VERSION="10"

setup_dotnet() {
    run_steps \
        install_dotnet \
        configure_dotnet_environment
}

has_dotnet_lts_sdk() {
    "$1" --list-sdks 2>/dev/null |
        grep -q "^${DOTNET_LTS_VERSION}\."
}

install_dotnet() {
    ! is_command_in_path "dotnet" || ! has_dotnet_lts_sdk "dotnet" || return 0

    case "$PLATFORM" in
        linux|wsl)
            case "$DISTRO" in
                ubuntu|debian)
                    sudo apt-get install -y "dotnet-sdk-${DOTNET_LTS_VERSION}.0"
                    ;;

                fedora)
                    sudo dnf install -y "dotnet-sdk-${DOTNET_LTS_VERSION}.0"
                    ;;

                arch)
                    sudo pacman -S --needed "dotnet-sdk-${DOTNET_LTS_VERSION}.0"
                    ;;

                *)
                    return 1
                    ;;
            esac
            ;;

        windows)
            is_command_in_path "winget.exe" || {
                printf 'WinGet is required to install .NET SDK.\n'
                return 1
            }

            winget.exe install --id "Microsoft.DotNet.SDK.${DOTNET_LTS_VERSION}" \
                --exact --source winget \
                --accept-package-agreements --accept-source-agreements
            ;;

        mac)
            is_command_in_path "brew" || {
                printf 'Homebrew is required to install .NET SDK.\n'
                return 1
            }

            brew install "dotnet@${DOTNET_LTS_VERSION}"
            ;;

        *)
            return 1
            ;;
    esac
}

configure_dotnet_environment() {
    local dotnet_executable
    local dotnet_root="${DOTNET_ROOT:-}"
    local dotnet_tools="$HOME/.dotnet/tools"

    case "$PLATFORM" in
        linux|wsl)
            dotnet_executable="$(find_executable --filter has_dotnet_lts_sdk \
                "${dotnet_root:+$dotnet_root/dotnet}" \
                "$HOME/.dotnet/dotnet" \
                "/usr/share/dotnet/dotnet" \
                "/usr/lib/dotnet/dotnet" \
                "/usr/lib64/dotnet/dotnet" \
                "/usr/local/share/dotnet/dotnet" \
                "/usr/local/bin/dotnet" \
                "/usr/bin/dotnet")"
            ;;

        windows)
            if [[ -n "$dotnet_root" ]]; then
                dotnet_root="$(windows_path_to_unix "$dotnet_root")" || return 1
            fi

            if [[ -n "$WINDOWS_USER_PROFILE" ]]; then
                dotnet_tools="$WINDOWS_USER_PROFILE/.dotnet/tools"
            fi

            dotnet_executable="$(find_executable --filter has_dotnet_lts_sdk \
                "${dotnet_root:+$dotnet_root/dotnet.exe}" \
                "$WINDOWS_PROGRAM_FILES/dotnet/dotnet.exe" \
                "${WINDOWS_LOCAL_APP_DATA:+$WINDOWS_LOCAL_APP_DATA/Microsoft/dotnet/dotnet.exe}" \
                "$HOME/.dotnet/dotnet.exe")"
            ;;

        mac)
            dotnet_executable="$(find_executable --filter has_dotnet_lts_sdk \
                "${dotnet_root:+$dotnet_root/dotnet}" \
                "$HOME/.dotnet/dotnet" \
                "/usr/local/share/dotnet/dotnet" \
                "/usr/local/share/dotnet/x64/dotnet" \
                "/opt/homebrew/opt/dotnet@${DOTNET_LTS_VERSION}/libexec/dotnet" \
                "/usr/local/opt/dotnet@${DOTNET_LTS_VERSION}/libexec/dotnet" \
                "/opt/homebrew/opt/dotnet/libexec/dotnet" \
                "/usr/local/opt/dotnet/libexec/dotnet" \
                "/opt/homebrew/bin/dotnet" \
                "/usr/local/bin/dotnet")"
            ;;

        *)
            return 1
            ;;
    esac

    [[ -n "$dotnet_executable" ]] || {
        printf '.NET SDK %s was installed, but its executable could not be found.\n' \
            "$DOTNET_LTS_VERSION"
        return 1
    }

    prepend_to_path "$dotnet_tools" || return 1
    prepend_to_path "${dotnet_executable%/*}" || return 1

    is_command_in_path "dotnet" && has_dotnet_lts_sdk "dotnet" || {
        printf '.NET SDK %s was installed, but it could not be added to PATH.\n' \
            "$DOTNET_LTS_VERSION"
        return 1
    }
}
