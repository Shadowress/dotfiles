setup_pyenv() {
    run_steps \
        install_pyenv \
        configure_pyenv_environment \
        configure_pyenv_settings
}

find_pyenv_executable() {
    local path_pyenv=""
    local pyenv_root="${PYENV_ROOT:-}"

    path_pyenv="$(command -v pyenv 2>/dev/null)" || :

    case "$PLATFORM" in
        linux|wsl)
            find_executable --filter is_executable_usable \
                "$path_pyenv" \
                "${pyenv_root:+$pyenv_root/bin/pyenv}" \
                "$HOME/.pyenv/bin/pyenv" \
                "/usr/local/bin/pyenv" \
                "/usr/bin/pyenv"
            ;;

        windows)
            find_executable --filter is_executable_usable \
                "$path_pyenv" \
                "$WINDOWS_USER_PROFILE/.pyenv/pyenv-win/bin/pyenv" \
                "$WINDOWS_USER_PROFILE/.pyenv/pyenv-win/bin/pyenv.bat" \
                "${WINDOWS_LOCAL_APP_DATA:+$WINDOWS_LOCAL_APP_DATA/pyenv/pyenv-win/bin/pyenv}" \
                "${WINDOWS_LOCAL_APP_DATA:+$WINDOWS_LOCAL_APP_DATA/pyenv/pyenv-win/bin/pyenv.bat}"
            ;;

        mac)
            find_executable --filter is_executable_usable \
                "$path_pyenv" \
                "/opt/homebrew/bin/pyenv" \
                "/usr/local/bin/pyenv" \
                "${pyenv_root:+$pyenv_root/bin/pyenv}" \
                "$HOME/.pyenv/bin/pyenv"
            ;;

        *)
            return 1
            ;;
    esac
}

install_pyenv() {
    find_pyenv_executable &>/dev/null && return 0

    case "$PLATFORM" in
        linux|wsl)
            clone_git_repository \
                "https://github.com/pyenv/pyenv.git" \
                "$HOME/.pyenv"
            ;;

        windows)
            clone_git_repository \
                "https://github.com/pyenv-win/pyenv-win.git" \
                "$WINDOWS_USER_PROFILE/.pyenv"
            ;;

        mac)
            is_command_in_path "brew" || {
                printf 'Homebrew is required to install pyenv.\n'
                return 1
            }

            brew install pyenv
            ;;

        *)
            return 1
            ;;
    esac
}

configure_windows_pyenv_environment() {
    local pyenv_executable="$1"
    local pyenv_root="${pyenv_executable%/bin/*}"
    local windows_pyenv_root

    windows_pyenv_root="$(cygpath -w "$pyenv_root")" || return 1

    export PYENV="$windows_pyenv_root"
    export PYENV_HOME="$windows_pyenv_root"
    export PYENV_ROOT="$windows_pyenv_root"

    is_command_in_path "powershell.exe" || {
        printf 'PowerShell is required to configure pyenv-win.\n'
        return 1
    }

    MSYS2_ARG_CONV_EXCL='*' powershell.exe \
        -NoProfile -ExecutionPolicy Bypass -Command '
            $ErrorActionPreference = "Stop"
            $root = $env:PYENV_ROOT
            $bin = Join-Path $root "bin"
            $shims = Join-Path $root "shims"

            [Environment]::SetEnvironmentVariable("PYENV", $root, "User")
            [Environment]::SetEnvironmentVariable("PYENV_HOME", $root, "User")
            [Environment]::SetEnvironmentVariable("PYENV_ROOT", $root, "User")

            $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
            $remaining = @(
                $userPath -split ";" |
                    Where-Object { $_ -and $_ -notin @($bin, $shims) }
            )
            $updatedPath = (@($bin, $shims) + $remaining) -join ";"
            [Environment]::SetEnvironmentVariable("Path", $updatedPath, "User")
        ' || return 1

    prepend_to_path "$pyenv_root/shims" || return 1
    prepend_to_path "$pyenv_root/bin"
}

configure_unix_pyenv_environment() {
    local pyenv_executable="$1"
    local initialization

    export PYENV_ROOT="${PYENV_ROOT:-$HOME/.pyenv}"
    prepend_to_path "${pyenv_executable%/*}" || return 1

    initialization="$("$pyenv_executable" init -)" || return 1
    eval "$initialization"
}

configure_pyenv_environment() {
    local pyenv_executable

    pyenv_executable="$(find_pyenv_executable)" || {
        printf 'pyenv was installed, but its executable could not be found or used.\n'
        return 1
    }

    case "$PLATFORM" in
        linux|wsl|mac)
            configure_unix_pyenv_environment "$pyenv_executable" || return 1
            ;;

        windows)
            configure_windows_pyenv_environment "$pyenv_executable" || return 1
            ;;

        *)
            return 1
            ;;
    esac

    is_command_in_path "pyenv" && is_executable_usable "pyenv" || {
        printf 'pyenv was installed, but it could not be added to PATH.\n'
        return 1
    }
}

add_pyenv_bash_startup_configuration() {
    local startup_file="$1"
    local pyenv_bin="$2"
    local quoted_pyenv_bin
    local root_configuration=
    local path_configuration
    local runtime_configuration=

    root_configuration='export PYENV_ROOT="${PYENV_ROOT:-$HOME/.pyenv}"'
    runtime_configuration='. "$HOME/.config/shell/pyenv.sh"'
    printf -v quoted_pyenv_bin '%q' "$pyenv_bin"
    path_configuration="[[ \":\$PATH:\" == *\":$quoted_pyenv_bin:\"* ]] || export PATH=$quoted_pyenv_bin:\"\$PATH\""

    touch "$startup_file" || return 1

    grep -Fqx "$root_configuration" "$startup_file" &&
        grep -Fqx "$path_configuration" "$startup_file" &&
        grep -Fqx "$runtime_configuration" "$startup_file" && return 0

    printf '\n' >> "$startup_file" || return 1
    grep -Fqx "$root_configuration" "$startup_file" ||
        printf '%s\n' "$root_configuration" >> "$startup_file"
    grep -Fqx "$path_configuration" "$startup_file" ||
        printf '%s\n' "$path_configuration" >> "$startup_file"
    grep -Fqx "$runtime_configuration" "$startup_file" ||
        printf '%s\n' "$runtime_configuration" >> "$startup_file"
}

configure_pyenv_settings() {
    local login_file
    local pyenv_executable

    [[ "$PLATFORM" != "windows" ]] || return 0

    pyenv_executable="$(find_pyenv_executable)" || return 1

    mkdir -p "$CONFIG/shell" &&
        link_path "$DOTFILES/config/shell/pyenv.sh" \
            "$CONFIG/shell/pyenv.sh" || return 1

    add_pyenv_bash_startup_configuration \
        "$HOME/.bashrc" "${pyenv_executable%/*}" || return 1

    if [[ -e "$HOME/.bash_profile" ]]; then
        login_file="$HOME/.bash_profile"
    elif [[ -e "$HOME/.bash_login" ]]; then
        login_file="$HOME/.bash_login"
    else
        login_file="$HOME/.profile"
    fi

    add_pyenv_bash_startup_configuration \
        "$login_file" "${pyenv_executable%/*}"
}
