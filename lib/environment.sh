is_command_in_path() {
    command -v "$1" &>/dev/null
}

find_executable() {
    local candidate
    local filter=""

    if [[ "${1:-}" == "--filter" ]]; then
        [[ -n "${2:-}" ]] || return 2

        filter="$2"
        shift 2
    fi

    for candidate in "$@"; do
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
        [[ "$source" -ef "$target" ]] || {
            printf 'Refusing to replace existing path: %s\n' "$target"
            return 1
        }

        return 0
    fi

    if [[ "$OS" != "windows" ]]; then
        ln -s "$source" "$target"
        return
    fi

    windows_source="$(cygpath -w "$source")" || return 1
    windows_target="$(cygpath -w "$target")" || return 1

    [[ -d "$source" ]] || return 1

    MSYS2_ARG_CONV_EXCL='*' \
        cmd.exe /d /c mklink /J "$windows_target" "$windows_source" >/dev/null
}
