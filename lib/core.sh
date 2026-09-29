load_setup_files() {
    local directory="$1"
    local setup_file

    [[ -d "$directory" ]] || {
        print_status "ERROR" "Setup Loader" "Directory not found: $directory"
        return 1
    }

    for setup_file in "$directory"/*.sh; do
        [[ -f "$setup_file" ]] || continue

        source "$setup_file" || {
            print_status "ERROR" "Setup Loader" "Failed to load: $setup_file"
            return 1
        }
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
