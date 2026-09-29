#!/usr/bin/env bash

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$HOME/.config"

source "$DOTFILES/lib/core.sh"
source "$DOTFILES/lib/environment.sh"
source "$DOTFILES/lib/logging.sh"
source "$DOTFILES/lib/package_manager.sh"
source "$DOTFILES/lib/platform.sh"

main() {
    detect_os || return 1

    load_setup_files "$DOTFILES/platforms/$OS" || return 1
    load_setup_files "$DOTFILES/apps" || return 1

    setup_directories || return 1

    reset_setup_counts

    prepare_package_manager || return 1

    setup_platform || return 1
    setup_shared || return 1

    print_setup_summary

    (( SETUP_FAILED <= 0 )) || return 1
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
