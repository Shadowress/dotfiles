WINDOWS_PROGRAM_FILES=""
WINDOWS_LOCAL_APP_DATA=""
WINDOWS_USER_PROFILE=""

detect_os() {
    local kernel
    kernel="$(uname -s)"

    case "$kernel" in
        Linux*)
            if grep -qi microsoft /proc/version; then
                OS="wsl"
            else
                OS="linux"
            fi

            detect_linux_distribution || return 1
            ;;

        CYGWIN*|MINGW*|MSYS*)
            OS="windows"
            ;;

        Darwin*)
            OS="mac"
            ;;

        *)
            print_status "ERROR" "Operating System" "Unsupported: $kernel"
            return 1
            ;;
    esac

    case "$OS" in
        windows|wsl)
            detect_windows_directories || return 1
            ;;
    esac
}

detect_windows_directories() {
    local windows_path

    case "$OS" in
        windows)
            WINDOWS_PROGRAM_FILES="/c/Program Files"
            WINDOWS_LOCAL_APP_DATA="$HOME/AppData/Local"
            WINDOWS_USER_PROFILE="$HOME"
            ;;

        wsl)
            WINDOWS_PROGRAM_FILES="/mnt/c/Program Files"
            WINDOWS_LOCAL_APP_DATA=""
            WINDOWS_USER_PROFILE=""
            ;;

        *)
            return 1
            ;;
    esac

    windows_path="${ProgramW6432:-${PROGRAMFILES:-${ProgramFiles:-}}}"
    if [[ -n "$windows_path" ]]; then
        WINDOWS_PROGRAM_FILES="$(windows_path_to_unix "$windows_path")" || return 1
    fi

    if [[ -n "${LOCALAPPDATA:-}" ]]; then
        WINDOWS_LOCAL_APP_DATA="$(windows_path_to_unix "$LOCALAPPDATA")" || return 1
    fi

    if [[ -n "${USERPROFILE:-}" ]]; then
        WINDOWS_USER_PROFILE="$(windows_path_to_unix "$USERPROFILE")" || return 1
    fi
}

detect_linux_distribution() {
    DISTRO="unknown"

    if [[ -f /etc/os-release ]]; then
        DISTRO="$(. /etc/os-release; printf '%s' "${ID:-unknown}")"
    fi

    case "$DISTRO" in
        ubuntu|debian|fedora|arch)
            ;;

        *)
            print_status "ERROR" "Linux Distribution" "Unsupported: $DISTRO"
            return 1
            ;;
    esac
}

windows_path_to_unix() {
    local windows_path="$1"

    [[ -n "$windows_path" ]] || return 1

    case "$windows_path" in
        /*)
            printf '%s\n' "$windows_path"
            return 0
            ;;
    esac

    if is_command_in_path "cygpath"; then
        cygpath -u "$windows_path"
    elif is_command_in_path "wslpath"; then
        wslpath -u "$windows_path"
    else
        return 1
    fi
}
