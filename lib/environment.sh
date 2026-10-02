is_command_in_path() {
    command -v "$1" &>/dev/null
}

initialize_user_environment() {
    local home_directory="${HOME:-}"
    local resolved_home

    if [[ -z "$home_directory" ]]; then
        print_status "ERROR" "Environment" \
            "HOME is empty. Run the installer as the user being configured."
        return 1
    fi

    case "$home_directory" in
        /*) ;;
        *)
            print_status "ERROR" "Environment" \
                "HOME must be an absolute path: $home_directory"
            return 1
            ;;
    esac

    if [[ ! -d "$home_directory" ]]; then
        print_status "ERROR" "Environment" \
            "HOME is not an existing directory: $home_directory"
        return 1
    fi

    resolved_home="$(cd "$home_directory" && pwd -P)" || {
        print_status "ERROR" "Environment" \
            "HOME could not be resolved: $home_directory"
        return 1
    }

    if [[ "$resolved_home" == "/" ]]; then
        print_status "ERROR" "Environment" \
            "HOME cannot resolve to the filesystem root (/)."
        return 1
    fi

    CONFIG="$home_directory/.config"
}

is_executable_usable() {
    "$1" --version &>/dev/null
}

find_executable() {
    local candidate
    local command_name
    local filter=""
    local path_executable=""

    if [[ "${1:-}" == "--filter" ]]; then
        [[ -n "${2:-}" ]] || return 2

        filter="$2"
        shift 2
    fi

    [[ -n "${1:-}" ]] || return 2
    command_name="$1"
    shift

    path_executable="$(command -v "$command_name" 2>/dev/null)" || :

    for candidate in "$path_executable" "$@"; do
        [[ -x "$candidate" ]] || continue
        [[ -z "$filter" ]] || "$filter" "$candidate" || continue

        printf '%s\n' "$candidate"
        return 0
    done

    return 1
}

prepend_to_path() {
    local directory="$1"
    local path_entry
    local updated_path=""
    local -a path_entries

    [[ -n "$directory" ]] || return 1

    IFS=: read -r -a path_entries <<< "${PATH:-}"

    for path_entry in "${path_entries[@]}"; do
        [[ "$path_entry" == "$directory" ]] && continue

        updated_path="${updated_path:+$updated_path:}$path_entry"
    done

    export PATH="$directory${updated_path:+:$updated_path}"

    hash -r
}

link_path() {
    local source="$1"
    local target="$2"
    local windows_source
    local windows_target

    [[ -e "$source" ]] || return 1

    if [[ -e "$target" || -L "$target" ]]; then
        [[ "$source" -ef "$target" ]] && return 0

        if [[ -L "$target" && "$PLATFORM" != "windows" ]]; then
            ln -sfn "$source" "$target"
            return
        fi

        if [[ ! -L "$target" ]]; then
            printf 'Refusing to replace existing path: %s\n' "$target"
            return 1
        fi
    fi

    if [[ "$PLATFORM" != "windows" ]]; then
        ln -s "$source" "$target"
        return
    fi

    windows_source="$(cygpath -w "$source")" || return 1
    windows_target="$(cygpath -w "$target")" || return 1

    [[ -d "$source" ]] || return 1

    if [[ -L "$target" ]]; then
        MSYS2_ARG_CONV_EXCL='*' \
            cmd.exe /d /c rmdir "$windows_target" >/dev/null || return 1
    fi

    MSYS2_ARG_CONV_EXCL='*' \
        cmd.exe /d /c mklink /J "$windows_target" "$windows_source" >/dev/null
}
