validate_wsl_gcm_argument() {
    local value="$1"
    local provided="$2"

    if [[ "$provided" == "true" && "$PLATFORM" != "wsl" ]]; then
        ARGUMENT_VALIDATION_ERROR="--wsl-gcm is only valid when running in WSL."
        return 1
    fi
}

validate_gcm_credential_store_argument() {
    local value="$1"

    [[ "$value" != "default" ]] || return 0

    select_git_credential_manager_backend || {
        ARGUMENT_VALIDATION_ERROR="Cannot determine the GCM backend used to validate --gcm-credential-store."
        return 1
    }

    case "$GIT_CREDENTIAL_MANAGER_BACKEND:$PLATFORM:$value" in
        windows:*:wincredman|windows:*:dpapi|windows:*:cache|\
        windows:*:plaintext|windows:*:none|\
        native:mac:keychain|native:mac:gpg|native:mac:cache|\
        native:mac:plaintext|native:mac:none|\
        native:linux:secretservice|native:linux:gpg|native:linux:cache|\
        native:linux:plaintext|native:linux:none|\
        native:wsl:secretservice|native:wsl:gpg|native:wsl:cache|\
        native:wsl:plaintext|native:wsl:none)
            return 0
            ;;
    esac

    ARGUMENT_VALIDATION_ERROR="Credential store '$value' is not supported by the $GIT_CREDENTIAL_MANAGER_BACKEND GCM backend on the $PLATFORM platform."
    return 1
}

register_argument \
    "gcm-credential-store" \
    "ARG_GCM_CREDENTIAL_STORE" \
    "enum" \
    "default" \
    "default|wincredman|dpapi|keychain|secretservice|gpg|cache|plaintext|none" \
    "validate_gcm_credential_store_argument" \
    "Select the credential store used by Git Credential Manager."

register_argument \
    "wsl-gcm" \
    "ARG_WSL_GCM" \
    "enum" \
    "auto" \
    "auto|native|windows" \
    "validate_wsl_gcm_argument" \
    "Select the Git Credential Manager backend used in WSL."
