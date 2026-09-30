source_shell_files() {
    local directory="$1"
    local loader_name="$2"
    local shell_file

    [[ -d "$directory" ]] || {
        print_status "ERROR" "$loader_name" "Directory not found: $directory"
        return 1
    }

    for shell_file in "$directory"/*.sh; do
        [[ -f "$shell_file" ]] || continue

        source "$shell_file" || {
            print_status "ERROR" "$loader_name" "Failed to load: $shell_file"
            return 1
        }
    done
}

find_value_index() {
    local requested="$1"
    shift
    local index=0
    local value

    for value in "$@"; do
        if [[ "$value" == "$requested" ]]; then
            printf '%s' "$index"
            return 0
        fi
        index=$((index + 1))
    done

    return 1
}

value_in_list() {
    find_value_index "$@" >/dev/null
}

join_values() {
    local delimiter="$1"
    shift
    local separator=""
    local value

    for value in "$@"; do
        printf '%s%s' "$separator" "$value"
        separator="$delimiter"
    done
}

setup_directories() {
    local output

    output=$(mkdir -p "$CONFIG" 2>&1) || {
        print_status "ERROR" "Directories" "$output"
        return 1
    }
}

run_steps() {
    local step

    for step in "$@"; do
        "$step" || return 1
    done
}
