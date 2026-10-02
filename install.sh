#!/usr/bin/env bash

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG=""

source "$DOTFILES/lib/arguments.sh"
source "$DOTFILES/lib/components.sh"
source "$DOTFILES/lib/core.sh"
source "$DOTFILES/lib/environment.sh"
source "$DOTFILES/lib/git.sh"
source "$DOTFILES/lib/logging.sh"
source "$DOTFILES/lib/package_manager.sh"
source "$DOTFILES/lib/platform.sh"

main() {
    source_shell_files "$DOTFILES/components/arguments" "Argument Loader" || return 1
    parse_arguments "$@" || return 1

    if [[ "$ARG_HELP" == "true" ]]; then
        print_install_help
        return 0
    fi

    initialize_user_environment || return 1

    detect_platform || return 1

    resolve_component_selection || return 1

    source_shell_files "$DOTFILES/platforms/$PLATFORM" "Setup Loader" || return 1
    source_shell_files "$DOTFILES/components" "Setup Loader" || return 1

    validate_arguments || return 1

    setup_directories || return 1

    reset_setup_counts

    prepare_package_manager || return 1

    setup_components || return 1

    print_setup_summary

    (( SETUP_FAILED <= 0 )) || return 1
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
