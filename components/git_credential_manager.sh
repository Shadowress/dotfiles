setup_git_credential_manager() {
    run_steps \
        install_git_credential_manager \
        configure_git_credential_manager_environment \
        configure_git_credential_manager_settings
}

GIT_CREDENTIAL_MANAGER_BACKEND=""

find_windows_git_credential_manager_executable() {
    find_executable --filter is_executable_usable \
        "git-credential-manager.exe" \
        "/ucrt64/bin/git-credential-manager.exe" \
        "/mingw64/bin/git-credential-manager.exe" \
        "/clangarm64/bin/git-credential-manager.exe" \
        "$WINDOWS_PROGRAM_FILES/Git/ucrt64/bin/git-credential-manager.exe" \
        "$WINDOWS_PROGRAM_FILES/Git/mingw64/bin/git-credential-manager.exe" \
        "$WINDOWS_PROGRAM_FILES/Git/clangarm64/bin/git-credential-manager.exe" \
        "${WINDOWS_LOCAL_APP_DATA:+$WINDOWS_LOCAL_APP_DATA/Programs/Git/ucrt64/bin/git-credential-manager.exe}" \
        "${WINDOWS_LOCAL_APP_DATA:+$WINDOWS_LOCAL_APP_DATA/Programs/Git/mingw64/bin/git-credential-manager.exe}" \
        "${WINDOWS_LOCAL_APP_DATA:+$WINDOWS_LOCAL_APP_DATA/Programs/Git/clangarm64/bin/git-credential-manager.exe}"
}

find_native_git_credential_manager_executable() {
    case "$PLATFORM" in
        linux|wsl)
            find_executable --filter is_executable_usable \
                "git-credential-manager" \
                "$HOME/.dotnet/tools/git-credential-manager" \
                "/usr/local/bin/git-credential-manager" \
                "/usr/bin/git-credential-manager"
            ;;

        mac)
            find_executable --filter is_executable_usable \
                "git-credential-manager" \
                "/opt/homebrew/bin/git-credential-manager" \
                "/usr/local/bin/git-credential-manager" \
                "/opt/homebrew/share/gcm-core/git-credential-manager" \
                "/usr/local/share/gcm-core/git-credential-manager"
            ;;

        *)
            return 1
            ;;
    esac
}

select_git_credential_manager_backend() {
    case "$PLATFORM" in
        windows)
            GIT_CREDENTIAL_MANAGER_BACKEND="windows"
            ;;

        linux|mac)
            GIT_CREDENTIAL_MANAGER_BACKEND="native"
            ;;

        wsl)
            case "$ARG_WSL_GCM" in
                native|windows)
                    GIT_CREDENTIAL_MANAGER_BACKEND="$ARG_WSL_GCM"
                    ;;

                auto)
                    if find_windows_git_credential_manager_executable &>/dev/null; then
                        GIT_CREDENTIAL_MANAGER_BACKEND="windows"
                    else
                        GIT_CREDENTIAL_MANAGER_BACKEND="native"
                    fi
                    ;;

                *)
                    return 1
                    ;;
            esac
            ;;

        *)
            return 1
            ;;
    esac
}

find_git_credential_manager_executable() {
    case "$GIT_CREDENTIAL_MANAGER_BACKEND" in
        windows)
            find_windows_git_credential_manager_executable
            ;;

        native)
            find_native_git_credential_manager_executable
            ;;

        *)
            return 1
            ;;
    esac
}

install_git_credential_manager() {
    select_git_credential_manager_backend || return 1

    find_git_credential_manager_executable &>/dev/null && return 0

    case "$GIT_CREDENTIAL_MANAGER_BACKEND" in
        windows)
            if [[ "$PLATFORM" == "wsl" ]]; then
                printf 'Windows Git Credential Manager was not found.\n'
            else
                printf 'Git Credential Manager was not found in the Git for Windows installation.\n'
            fi
            return 1
            ;;

        native)
            case "$PLATFORM" in
                linux|wsl)
                    is_command_in_path "dotnet" || {
                        printf '.NET SDK is required to install Git Credential Manager.\n'
                        return 1
                    }

                    dotnet tool install -g git-credential-manager
                    ;;

                mac)
                    is_command_in_path "brew" || {
                        printf 'Homebrew is required to install Git Credential Manager.\n'
                        return 1
                    }

                    brew install --cask git-credential-manager
                    ;;

                *)
                    return 1
                    ;;
            esac
            ;;

        *)
            printf 'Git Credential Manager backend was not selected.\n'
            return 1
            ;;
    esac
}

configure_git_credential_manager_environment() {
    local credential_manager_executable

    credential_manager_executable="$(find_git_credential_manager_executable)" || {
        printf 'Git Credential Manager was installed, but its executable could not be found or used.\n'
        return 1
    }

    if [[ "$PLATFORM" == "wsl" && \
        "$GIT_CREDENTIAL_MANAGER_BACKEND" == "windows" ]]; then
        return 0
    fi

    prepend_to_path "${credential_manager_executable%/*}" || return 1

    is_executable_usable "$credential_manager_executable" || {
        printf 'Git Credential Manager was found, but it could not be used.\n'
        return 1
    }
}

default_git_credential_store() {
    case "$GIT_CREDENTIAL_MANAGER_BACKEND:$PLATFORM" in
        native:linux) printf 'secretservice\n' ;;
        native:wsl) printf 'cache\n' ;;
        native:mac|windows:windows|windows:wsl) ;;
        *) return 1 ;;
    esac
}

configure_git_credential_store() {
    local credential_store="$ARG_GCM_CREDENTIAL_STORE"

    if [[ "$credential_store" == "default" ]]; then
        credential_store="$(default_git_credential_store)" || return 1
    fi

    if [[ -z "$credential_store" ]]; then
        git config --file "$HOME/.gitconfig.local" \
            --unset-all credential.credentialStore 2>/dev/null || :
        return 0
    fi

    git config --file "$HOME/.gitconfig.local" --replace-all \
        credential.credentialStore "$credential_store"
}

escape_git_credential_helper_path() {
    local helper_path="$1"

    helper_path="${helper_path//\\/\\\\}"
    helper_path="${helper_path// /\\ }"
    helper_path="${helper_path//(/\\(}"
    helper_path="${helper_path//)/\\)}"

    printf '%s\n' "$helper_path"
}

configure_git_credential_manager_settings() {
    local credential_manager_executable
    local credential_manager_helper

    credential_manager_executable="$(find_git_credential_manager_executable)" || {
        printf 'Git Credential Manager executable could not be found.\n'
        return 1
    }

    credential_manager_helper="$(
        escape_git_credential_helper_path "$credential_manager_executable"
    )" || return 1

    if [[ "$PLATFORM" == "windows" ]]; then
        git config --file "$HOME/.gitconfig.local" \
            --replace-all credential.helper "" &&
            MSYS2_ARG_CONV_EXCL="$credential_manager_helper" \
                git config --file "$HOME/.gitconfig.local" --add \
                    credential.helper "$credential_manager_helper" || return 1
    else
        git config --file "$HOME/.gitconfig.local" \
            --replace-all credential.helper "" &&
            git config --file "$HOME/.gitconfig.local" --add \
                credential.helper "$credential_manager_helper" || return 1
    fi

    configure_git_credential_store
}
