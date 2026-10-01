clone_git_repository() {
    local repository="$1"
    local destination="$2"

    is_command_in_path "git" || {
        printf 'Git is required to clone repositories.\n'
        return 1
    }

    if [[ -e "$destination" || -L "$destination" ]]; then
        printf 'Refusing to replace existing repository path: %s\n' \
            "$destination"
        return 1
    fi

    git clone --depth 1 "$repository" "$destination"
}
