#!/usr/bin/env bash

set -uo pipefail

probe_root="$(cygpath -u "$1")"
test_root="$(cygpath -u "$2")"
source "$test_root/lib/environment.sh"

PLATFORM="windows"
source_one="$probe_root/source-one"
source_two="$probe_root/source-two"
target="$probe_root/target"

link_path "$source_one" "$target" || exit 1
link_path "$source_one" "$target" || exit 1
link_path "$source_two" "$target" || exit 1

[[ "$source_two" -ef "$target" ]]
