ARGUMENT_NAMES=()
ARGUMENT_VARIABLES=()
ARGUMENT_TYPES=()
ARGUMENT_DEFAULTS=()
ARGUMENT_CHOICES=()
ARGUMENT_VALIDATORS=()
ARGUMENT_DESCRIPTIONS=()
ARGUMENT_ALIASES=()
ARGUMENT_VALUE_LABELS=()
ARGUMENT_PROVIDED=()

argument_error() {
    print_status "ERROR" "Arguments" "$1" >&2
}

normalize_argument_value() {
    local type="$1"
    local value="$2"
    local choices="$3"
    local choice
    local -a available_choices

    case "$type" in
        string)
            ARGUMENT_NORMALIZED_VALUE="$value"
            ;;

        boolean)
            case "$value" in
                true|yes|1|on)
                    ARGUMENT_NORMALIZED_VALUE="true"
                    ;;
                false|no|0|off)
                    ARGUMENT_NORMALIZED_VALUE="false"
                    ;;
                *)
                    return 1
                    ;;
            esac
            ;;

        integer)
            [[ "$value" =~ ^-?[0-9]+$ ]] || return 1
            ARGUMENT_NORMALIZED_VALUE="$value"
            ;;

        enum)
            IFS='|' read -r -a available_choices <<< "$choices"
            for choice in "${available_choices[@]}"; do
                if [[ "$value" == "$choice" ]]; then
                    ARGUMENT_NORMALIZED_VALUE="$value"
                    return 0
                fi
            done
            return 1
            ;;

        *)
            return 1
            ;;
    esac
}

argument_type_description() {
    local type="$1"
    local choices="$2"

    case "$type" in
        boolean) printf 'a boolean (true or false)' ;;
        integer) printf 'an integer' ;;
        enum) printf 'one of: %s' "${choices//|/, }" ;;
        string) printf 'a string' ;;
        *) printf 'a valid %s value' "$type" ;;
    esac
}

find_argument() {
    ARGUMENT_INDEX="$(find_value_index "$1" "${ARGUMENT_NAMES[@]}")" || {
        ARGUMENT_INDEX=""
        return 1
    }
}

find_argument_alias() {
    ARGUMENT_INDEX="$(find_value_index "$1" "${ARGUMENT_ALIASES[@]}")" || {
        ARGUMENT_INDEX=""
        return 1
    }
}

argument_was_provided() {
    find_argument "$1" || return 1
    [[ "${ARGUMENT_PROVIDED[$ARGUMENT_INDEX]}" == "true" ]]
}

register_argument() {
    local name="$1"
    local variable="$2"
    local type="$3"
    local default_value="$4"
    local choices="${5:-}"
    local validator="${6:-}"
    local description="${7:-}"
    local alias="${8:-}"
    local value_label="${9:-value}"
    local index

    [[ "$name" =~ ^[a-z][a-z0-9-]*$ ]] || {
        argument_error "Invalid registered name: --$name."
        return 1
    }
    [[ "$variable" =~ ^ARG_[A-Z][A-Z0-9_]*$ ]] || {
        argument_error "Invalid storage variable for --$name: $variable."
        return 1
    }
    case "$type" in
        boolean|enum|integer|string) ;;
        *)
            argument_error "Invalid type registered for --$name: $type."
            return 1
            ;;
    esac
    [[ "$type" != "enum" || -n "$choices" ]] || {
        argument_error "No accepted values were registered for --$name."
        return 1
    }
    [[ -z "$alias" || "$alias" =~ ^[a-zA-Z0-9?]$ ]] || {
        argument_error "Invalid alias registered for --$name: -$alias."
        return 1
    }
    [[ "$value_label" =~ ^[a-z][a-z-]*$ ]] || {
        argument_error \
            "Invalid value label registered for --$name: $value_label."
        return 1
    }
    find_argument "$name" && {
        argument_error "Argument --$name was registered more than once."
        return 1
    }
    for index in "${!ARGUMENT_VARIABLES[@]}"; do
        [[ "${ARGUMENT_VARIABLES[$index]}" != "$variable" ]] || {
            argument_error "Storage variable $variable was registered more than once."
            return 1
        }
        [[ -z "$alias" || "${ARGUMENT_ALIASES[$index]}" != "$alias" ]] || {
            argument_error "Alias -$alias was registered more than once."
            return 1
        }
    done
    normalize_argument_value "$type" "$default_value" "$choices" || {
        argument_error "Invalid default value for --$name: $default_value."
        return 1
    }

    index=${#ARGUMENT_NAMES[@]}
    ARGUMENT_NAMES[$index]="$name"
    ARGUMENT_VARIABLES[$index]="$variable"
    ARGUMENT_TYPES[$index]="$type"
    ARGUMENT_DEFAULTS[$index]="$ARGUMENT_NORMALIZED_VALUE"
    ARGUMENT_CHOICES[$index]="$choices"
    ARGUMENT_VALIDATORS[$index]="$validator"
    ARGUMENT_DESCRIPTIONS[$index]="$description"
    ARGUMENT_ALIASES[$index]="$alias"
    ARGUMENT_VALUE_LABELS[$index]="$value_label"
    ARGUMENT_PROVIDED[$index]="false"
}

initialize_argument_values() {
    local index

    for ((index = 0; index < ${#ARGUMENT_NAMES[@]}; index++)); do
        printf -v "${ARGUMENT_VARIABLES[$index]}" '%s' \
            "${ARGUMENT_DEFAULTS[$index]}"
        ARGUMENT_PROVIDED[$index]="false"
    done
}

parse_arguments() {
    local token
    local name
    local value
    local index
    local variable
    local type
    local choices

    initialize_argument_values || return 1

    while (($# > 0)); do
        token="$1"
        shift

        case "$token" in
            --*=*)
                name="${token%%=*}"
                name="${name#--}"
                value="${token#*=}"
                ;;

            --*)
                name="${token#--}"
                find_argument "$name" || {
                    argument_error \
                        "Unknown option: $token. Run 'bash install.sh --help' for usage."
                    return 1
                }
                index="$ARGUMENT_INDEX"

                if [[ "${ARGUMENT_TYPES[$index]}" == "boolean" ]] && \
                    { (($# == 0)) || [[ "$1" == -* ]]; }; then
                    value="true"
                elif (($# > 0)) && [[ "$1" != --* ]]; then
                    value="$1"
                    shift
                else
                    argument_error "Argument --$name requires a value."
                    return 1
                fi
                ;;

            -?)
                name=""
                find_argument_alias "${token#-}" || {
                    argument_error \
                        "Unknown option: $token. Run 'bash install.sh --help' for usage."
                    return 1
                }
                index="$ARGUMENT_INDEX"
                name="${ARGUMENT_NAMES[$index]}"

                if [[ "${ARGUMENT_TYPES[$index]}" == "boolean" ]] && \
                    { (($# == 0)) || [[ "$1" == -* ]]; }; then
                    value="true"
                elif (($# > 0)) && [[ "$1" != -* ]]; then
                    value="$1"
                    shift
                else
                    argument_error "Argument -${token#-} requires a value."
                    return 1
                fi
                ;;

            -*)
                argument_error \
                    "Unknown option: $token. Run 'bash install.sh --help' for usage."
                return 1
                ;;

            *)
                argument_error "Unexpected positional argument: $token."
                return 1
                ;;
        esac

        find_argument "$name" || {
            argument_error \
                "Unknown option: --$name. Run 'bash install.sh --help' for usage."
            return 1
        }
        index="$ARGUMENT_INDEX"
        [[ "${ARGUMENT_PROVIDED[$index]}" != "true" ]] || {
            argument_error "Argument --$name was provided more than once."
            return 1
        }

        type="${ARGUMENT_TYPES[$index]}"
        choices="${ARGUMENT_CHOICES[$index]}"
        normalize_argument_value "$type" "$value" "$choices" || {
            argument_error \
                "Invalid value for --$name: '$value'; expected $(argument_type_description "$type" "$choices")."
            return 1
        }

        variable="${ARGUMENT_VARIABLES[$index]}"
        printf -v "$variable" '%s' "$ARGUMENT_NORMALIZED_VALUE"
        ARGUMENT_PROVIDED[$index]="true"
    done
}

print_argument_help() {
    local index
    local option

    for ((index = 0; index < ${#ARGUMENT_NAMES[@]}; index++)); do
        option="--${ARGUMENT_NAMES[$index]}"
        if [[ -n "${ARGUMENT_ALIASES[$index]}" ]]; then
            option="-${ARGUMENT_ALIASES[$index]}, $option"
        fi
        if [[ "${ARGUMENT_TYPES[$index]}" != "boolean" ]]; then
            option="$option <${ARGUMENT_VALUE_LABELS[$index]}>"
        fi

        printf '  %-34s %s\n' "$option" "${ARGUMENT_DESCRIPTIONS[$index]}"
        if [[ "${ARGUMENT_TYPES[$index]}" == "enum" ]]; then
            printf '  %-34s Values: %s.\n' "" \
                "${ARGUMENT_CHOICES[$index]//|/, }"
        fi
    done
}

validate_arguments() {
    local index
    local validator
    local variable

    for ((index = 0; index < ${#ARGUMENT_NAMES[@]}; index++)); do
        validator="${ARGUMENT_VALIDATORS[$index]}"
        [[ -n "$validator" ]] || continue
        declare -F "$validator" >/dev/null || {
            argument_error \
                "Validator for --${ARGUMENT_NAMES[$index]} was not found: $validator."
            return 1
        }

        variable="${ARGUMENT_VARIABLES[$index]}"
        ARGUMENT_VALIDATION_ERROR=""
        "$validator" "${!variable}" "${ARGUMENT_PROVIDED[$index]}" || {
            argument_error \
                "${ARGUMENT_VALIDATION_ERROR:-Validation failed for --${ARGUMENT_NAMES[$index]}.}"
            return 1
        }
    done
}
