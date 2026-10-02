COMPONENT_NAMES=()
COMPONENT_DISPLAY_NAMES=()
COMPONENT_SETUP_FUNCTIONS=()
COMPONENT_PLATFORMS=()
COMPONENT_DEPENDENCIES=()

register_component() {
    COMPONENT_NAMES+=("$1")
    COMPONENT_DISPLAY_NAMES+=("$2")
    COMPONENT_SETUP_FUNCTIONS+=("$3")
    COMPONENT_PLATFORMS+=("$4")
    COMPONENT_DEPENDENCIES+=("${5:-}")
}

register_component "dotnet" ".NET SDK" "setup_dotnet" "all"
register_component "git" "Git" "setup_git" "all"
register_component "gcm" "Git Credential Manager" \
    "setup_git_credential_manager" "all" "git"
register_component "homebrew" "Homebrew" "setup_homebrew" "mac"
register_component "nvim" "Neovim" "setup_nvim" "all"
register_component "pyenv" "Python Version Manager" "setup_pyenv" "all"

MINIMAL_COMPONENTS=(
    "git"
    "gcm"
)

SELECTED_COMPONENTS=()
PARSED_COMPONENTS=()

component_exists() {
    find_component_index "$1" >/dev/null
}

find_component_index() {
    find_value_index "$1" "${COMPONENT_NAMES[@]}"
}

component_display_name() {
    local index

    index="$(find_component_index "$1")" || return 1
    printf '%s' "${COMPONENT_DISPLAY_NAMES[$index]}"
}

component_platforms() {
    local index

    index="$(find_component_index "$1")" || return 1
    printf '%s' "${COMPONENT_PLATFORMS[$index]}"
}

component_dependencies() {
    local index

    index="$(find_component_index "$1")" || return 1
    printf '%s' "${COMPONENT_DEPENDENCIES[$index]}"
}

platform_display_name() {
    case "$1" in
        all) printf 'All' ;;
        linux) printf 'Linux' ;;
        mac) printf 'macOS' ;;
        windows) printf 'Windows' ;;
        wsl) printf 'WSL' ;;
        *) return 1 ;;
    esac
}

component_platforms_text() {
    local component="$1"
    local platform
    local platforms
    local separator=""
    local -a platform_list

    platforms="$(component_platforms "$component")" || return 1
    IFS='|' read -r -a platform_list <<< "$platforms"
    for platform in "${platform_list[@]}"; do
        printf '%s%s' "$separator" "$(platform_display_name "$platform")"
        separator=", "
    done
}

component_is_available_on_platform() {
    local component="$1"
    local current_platform="$2"
    local available_platform
    local platforms
    local -a platform_list

    platforms="$(component_platforms "$component")" || return 1
    IFS='|' read -r -a platform_list <<< "$platforms"
    for available_platform in "${platform_list[@]}"; do
        [[ "$available_platform" != "all" && \
            "$available_platform" != "$current_platform" ]] || return 0
    done

    return 1
}

component_in_list() {
    value_in_list "$@"
}

component_names_text() {
    join_values ", " "${COMPONENT_NAMES[@]}"
}

minimal_component_names_text() {
    join_values ", " "${MINIMAL_COMPONENTS[@]}"
}

validate_component_registry() {
    local component
    local index
    local platform
    local platforms
    local dependency
    local dependency_index
    local dependency_position
    local dependencies
    local -a platform_list
    local -a dependency_list

    if (( ${#COMPONENT_NAMES[@]} == 0 )) ||
        (( ${#COMPONENT_NAMES[@]} != ${#COMPONENT_DISPLAY_NAMES[@]} )) ||
        (( ${#COMPONENT_NAMES[@]} != ${#COMPONENT_SETUP_FUNCTIONS[@]} )) ||
        (( ${#COMPONENT_NAMES[@]} != ${#COMPONENT_PLATFORMS[@]} )) ||
        (( ${#COMPONENT_NAMES[@]} != ${#COMPONENT_DEPENDENCIES[@]} )); then
        argument_error "The component registry is inconsistent."
        return 1
    fi

    for ((index = 0; index < ${#COMPONENT_NAMES[@]}; index++)); do
        component="${COMPONENT_NAMES[$index]}"
        [[ "$component" =~ ^[a-z][a-z0-9-]*$ ]] || {
            argument_error "Invalid registered component name: $component."
            return 1
        }
        component_in_list "$component" "${COMPONENT_NAMES[@]:0:$index}" && {
            argument_error "Component '$component' was registered more than once."
            return 1
        }

        platforms="${COMPONENT_PLATFORMS[$index]}"
        [[ -n "$platforms" ]] || {
            argument_error "Component '$component' has no available platforms."
            return 1
        }
        IFS='|' read -r -a platform_list <<< "$platforms"
        for platform in "${platform_list[@]}"; do
            platform_display_name "$platform" >/dev/null || {
                argument_error \
                    "Component '$component' has an invalid platform: $platform."
                return 1
            }
        done
        if [[ "$platforms" != "all" ]] &&
            component_in_list "all" "${platform_list[@]}"; then
            argument_error \
                "Component '$component' cannot combine 'all' with another platform."
            return 1
        fi

        dependencies="${COMPONENT_DEPENDENCIES[$index]}"
        [[ -z "$dependencies" ]] || {
            IFS='|' read -r -a dependency_list <<< "$dependencies"
            for ((dependency_position = 0;
                dependency_position < ${#dependency_list[@]};
                dependency_position++)); do
                dependency="${dependency_list[$dependency_position]}"
                dependency_index="$(find_component_index "$dependency")" || {
                    argument_error \
                        "Component '$component' has an unknown dependency: $dependency."
                    return 1
                }
                (( dependency_index < index )) || {
                    argument_error \
                        "Component '$component' must be registered after dependency '$dependency'."
                    return 1
                }
                component_in_list "$dependency" \
                    "${dependency_list[@]:0:$dependency_position}" && {
                    argument_error \
                        "Component '$component' lists dependency '$dependency' more than once."
                    return 1
                }
            done
        }
    done

    for ((index = 0; index < ${#MINIMAL_COMPONENTS[@]}; index++)); do
        component="${MINIMAL_COMPONENTS[$index]}"
        component_exists "$component" || {
            argument_error \
                "Minimal component '$component' is not registered."
            return 1
        }
        component_in_list "$component" "${MINIMAL_COMPONENTS[@]:0:$index}" && {
            argument_error \
                "Minimal component '$component' was listed more than once."
            return 1
        }
    done

    return 0
}

parse_component_list() {
    local value="$1"
    local component
    local -a components

    PARSED_COMPONENTS=()
    case "$value" in
        ""|,*|*,|*,,*)
            argument_error \
                "Invalid component list '$value'; use comma-separated component names."
            return 1
            ;;
    esac

    IFS=',' read -r -a components <<< "$value"
    for component in "${components[@]}"; do
        component_exists "$component" || {
            argument_error \
                "Unknown component '$component'. Valid components: $(component_names_text)."
            return 1
        }
        component_in_list "$component" "${PARSED_COMPONENTS[@]}" && {
            argument_error "Component '$component' was listed more than once."
            return 1
        }
        PARSED_COMPONENTS+=("$component")
    done
}

resolve_component_selection() {
    local only_provided="false"
    local include_provided="false"
    local skip_provided="false"
    local component
    local dependency
    local dependencies
    local -a only_components=()
    local -a include_components=()
    local -a skip_components=()
    local -a remaining_components=()
    local -a available_components=()
    local -a dependency_list=()

    validate_component_registry || return 1
    argument_was_provided "only" && only_provided="true"
    argument_was_provided "include" && include_provided="true"
    argument_was_provided "skip" && skip_provided="true"

    if [[ "$only_provided" == "true" ]]; then
        parse_component_list "$ARG_ONLY" || return 1
        only_components=("${PARSED_COMPONENTS[@]}")
    fi
    if [[ "$include_provided" == "true" ]]; then
        parse_component_list "$ARG_INCLUDE" || return 1
        include_components=("${PARSED_COMPONENTS[@]}")
    fi
    if [[ "$skip_provided" == "true" ]]; then
        parse_component_list "$ARG_SKIP" || return 1
        skip_components=("${PARSED_COMPONENTS[@]}")
    fi

    if [[ "$only_provided" == "true" && "$ARG_MINIMAL" == "true" ]]; then
        argument_error "--only cannot be combined with --minimal."
        return 1
    fi
    if [[ "$only_provided" == "true" && "$include_provided" == "true" ]]; then
        argument_error "--only cannot be combined with --include."
        return 1
    fi
    if [[ "$only_provided" == "true" && "$skip_provided" == "true" ]]; then
        argument_error "--only cannot be combined with --skip."
        return 1
    fi
    if [[ "$include_provided" == "true" && "$ARG_MINIMAL" != "true" ]]; then
        argument_error "--include requires --minimal."
        return 1
    fi

    for component in "${include_components[@]}"; do
        component_in_list "$component" "${skip_components[@]}" || continue
        argument_error \
            "Component '$component' cannot be both included and skipped."
        return 1
    done

    if [[ "$only_provided" == "true" ]]; then
        SELECTED_COMPONENTS=("${only_components[@]}")
    elif [[ "$ARG_MINIMAL" == "true" ]]; then
        SELECTED_COMPONENTS=("${MINIMAL_COMPONENTS[@]}")
    else
        SELECTED_COMPONENTS=("${COMPONENT_NAMES[@]}")
    fi

    for component in "${include_components[@]}"; do
        component_in_list "$component" "${SELECTED_COMPONENTS[@]}" ||
            SELECTED_COMPONENTS+=("$component")
    done

    for component in "${SELECTED_COMPONENTS[@]}"; do
        component_in_list "$component" "${skip_components[@]}" ||
            remaining_components+=("$component")
    done
    SELECTED_COMPONENTS=("${remaining_components[@]}")

    for component in "${SELECTED_COMPONENTS[@]}"; do
        if component_is_available_on_platform "$component" "$PLATFORM"; then
            available_components+=("$component")
            continue
        fi

        if component_in_list "$component" \
            "${only_components[@]}" "${include_components[@]}"; then
            argument_error \
                "Component '$component' is platform-specific and only available on: $(component_platforms_text "$component") (current platform: $(platform_display_name "$PLATFORM"))."
            return 1
        fi
    done
    SELECTED_COMPONENTS=("${available_components[@]}")

    for component in "${SELECTED_COMPONENTS[@]}"; do
        dependencies="$(component_dependencies "$component")" || return 1
        [[ -z "$dependencies" ]] || {
            IFS='|' read -r -a dependency_list <<< "$dependencies"
            for dependency in "${dependency_list[@]}"; do
                component_in_list "$dependency" "${SELECTED_COMPONENTS[@]}" || {
                    argument_error \
                        "Component '$component' requires component '$dependency' to be selected."
                    return 1
                }
            done
        }
    done
}

component_is_selected() {
    component_in_list "$1" "${SELECTED_COMPONENTS[@]}"
}

setup_components() {
    local index
    local component
    local dependency
    local dependency_index
    local dependencies
    local display_name
    local setup_function
    local -a dependency_list
    local -a results=()

    for ((index = 0; index < ${#COMPONENT_NAMES[@]}; index++)); do
        component="${COMPONENT_NAMES[$index]}"
        component_is_available_on_platform "$component" "$PLATFORM" || continue

        display_name="${COMPONENT_DISPLAY_NAMES[$index]}"
        setup_function="${COMPONENT_SETUP_FUNCTIONS[$index]}"

        if component_is_selected "$component"; then
            dependencies="${COMPONENT_DEPENDENCIES[$index]}"
            if [[ -n "$dependencies" ]]; then
                IFS='|' read -r -a dependency_list <<< "$dependencies"
                for dependency in "${dependency_list[@]}"; do
                    dependency_index="$(find_component_index "$dependency")" || return 1
                    [[ "${results[$dependency_index]:-}" == "succeeded" ]] || {
                        SETUP_TOTAL=$((SETUP_TOTAL + 1))
                        SETUP_FAILED=$((SETUP_FAILED + 1))
                        print_status "ERROR" "$display_name" \
                            "Dependency failed: $(component_display_name "$dependency")."
                        results[$index]="failed"
                        continue 2
                    }
                done
            fi

            if run_setup "$display_name" "$setup_function"; then
                results[$index]="succeeded"
            else
                results[$index]="failed"
            fi
        else
            print_status "INFO" "$display_name" "Not selected."
            results[$index]="skipped"
        fi
    done
}

print_install_help() {
    local component

    cat <<EOF
Usage: bash install.sh [options]

Install and configure selected dotfile components.

Options:
EOF
    print_argument_help

    printf '\nComponents:\n'
    for component in "${COMPONENT_NAMES[@]}"; do
        printf '  %-16s %-24s %s\n' \
            "$component" \
            "$(component_display_name "$component")" \
            "$(component_platforms_text "$component")"
    done

    printf '\nMinimal Components:\n'
    for component in "${MINIMAL_COMPONENTS[@]}"; do
        printf '  %-16s %-24s %s\n' \
            "$component" \
            "$(component_display_name "$component")" \
            "$(component_platforms_text "$component")"
    done
}
