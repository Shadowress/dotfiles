if [[ -z "${DOTFILES_PYENV_INITIALIZED:-}" ]] &&
    command -v pyenv >/dev/null 2>&1; then
    eval "$(pyenv init -)"
    DOTFILES_PYENV_INITIALIZED="true"
fi
