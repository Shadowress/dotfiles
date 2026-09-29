SETUP_TOTAL=0
SETUP_SUCCEEDED=0
SETUP_FAILED=0

reset_setup_counts() {
    SETUP_TOTAL=0
    SETUP_SUCCEEDED=0
    SETUP_FAILED=0
}

print_status() {
    local level="$1"
    local component="$2"
    local message="${3:-}"

    if [[ -n "$message" ]]; then
        printf '[%s] %s: %s\n' "$level" "$component" "${message//$'\n'/$'\n        '}"
    else
        printf '[%s] %s\n' "$level" "$component"
    fi
}

run_setup() {
    local name="$1"
    local setup_function="$2"

    SETUP_TOTAL=$((SETUP_TOTAL + 1))

    if "$setup_function"; then
        SETUP_SUCCEEDED=$((SETUP_SUCCEEDED + 1))
        print_status "OK" "$name"
        return 0
    fi

    SETUP_FAILED=$((SETUP_FAILED + 1))
    print_status "ERROR" "$name"
    return 1
}

print_setup_summary() {
    printf '\n'
    print_status "SUMMARY" "Setups" "$SETUP_SUCCEEDED/$SETUP_TOTAL succeeded"
}
