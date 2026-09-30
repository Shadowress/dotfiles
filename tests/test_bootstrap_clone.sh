#!/usr/bin/env bash

set -euo pipefail

TEST_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$TEST_ROOT/tests/lib/test_helpers.sh"

PROBE_DIRECTORY="$(make_test_directory dotfiles-bootstrap-network)"
trap 'remove_test_directory "$PROBE_DIRECTORY" dotfiles-bootstrap-network' EXIT

HOME="$PROBE_DIRECTORY"
export HOME

BOOTSTRAP_DEFINITIONS="$(
    script_before_line "$TEST_ROOT/bootstrap.sh" 'main "$@"'
)"
eval "$BOOTSTRAP_DEFINITIONS"

find_usable_git || fail "Git" "A usable Git installation is required for this test."
clone_repository
validate_existing_repository

print_status "OK" "Test" "HTTPS clone integration succeeded."
