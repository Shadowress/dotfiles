#!/usr/bin/env bash

set -euo pipefail

TEST_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROBE_DIRECTORY="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-bootstrap-entry.XXXXXX")"

cleanup() {
    case "$PROBE_DIRECTORY" in
        "${TMPDIR:-/tmp}"/dotfiles-bootstrap-entry.*)
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

repository="$PROBE_DIRECTORY/.dotfiles"
mkdir -p "$repository"
GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null \
    git -c core.excludesFile=/dev/null -C "$repository" init --quiet
GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null \
    git -C "$repository" remote add origin \
    https://github.com/Shadowress/dotfiles.git
printf '%s\n' \
    '#!/usr/bin/env bash' \
    'printf '\''[OK] Fixture: installer received <%s>\n'\'' "$1"' \
    > "$repository/install.sh"

output="$(
    HOME="$PROBE_DIRECTORY" bash "$TEST_ROOT/bootstrap.sh" \
        'literal;not-a-command'
)"

[[ "$output" == *'[OK] Fixture: installer received <literal;not-a-command>'* ]]
[[ "$output" == *'[OK] Bootstrap: Installation completed.'* ]]

mv "$repository" "$PROBE_DIRECTORY/valid-repository"
printf 'not a repository\n' > "$repository"
set +e
failure_output="$(
    HOME="$PROBE_DIRECTORY" bash "$TEST_ROOT/bootstrap.sh" 2>&1
)"
failure_status=$?
set -e

[[ $failure_status -ne 0 ]]
[[ "$failure_output" == *'[ERROR] Dotfiles:'* ]]

printf '[OK] Test: Bootstrap shell entry point succeeded\n'
