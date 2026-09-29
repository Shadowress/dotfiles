#!/usr/bin/env bash

set -euo pipefail

TEST_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROBE_DIRECTORY="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-bootstrap-network.XXXXXX")"

cleanup() {
    case "$PROBE_DIRECTORY" in
        "${TMPDIR:-/tmp}"/dotfiles-bootstrap-network.*)
            rm -rf -- "$PROBE_DIRECTORY"
            ;;

        *)
            printf 'Refusing to remove unexpected test path: %s\n' \
                "$PROBE_DIRECTORY" >&2
            return 1
            ;;
    esac
}
trap cleanup EXIT

HOME="$PROBE_DIRECTORY"
export HOME

BOOTSTRAP_DEFINITIONS="$(
    awk '/^main "\$@"$/ { exit } { print }' "$TEST_ROOT/bootstrap.sh"
)"
eval "$BOOTSTRAP_DEFINITIONS"

find_usable_git || fail "Git" "A usable Git installation is required for this test."
clone_repository
validate_existing_repository

print_status "OK" "Test" "HTTPS clone integration succeeded."
