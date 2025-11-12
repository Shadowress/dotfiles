set -e

DOTFILES="$HOME/.dotfiles"
CONFIG="$HOME/.config"

case "$(uname -s)" in
    Linux*)
        if grep -qi microsoft /proc/version; then
            OS="wsl"
        else
            OS="linux"
        fi
        ;;
    Darwin*) OS="mac" ;;
    CYGWIN*|MINGW*|MSYS*) OS="windows" ;;
    *) OS="unknown" ;;
esac

mkdir -p "$CONFIG"
touch "$DOTFILES/common/git/.gitconfig.local"

ln -sf "$DOTFILES/common/git/.gitconfig" "$HOME/.gitconfig"
ln -sf "$DOTFILES/common/git/.gitconfig.local" "$HOME/.gitconfig.local"
ln -sf "$DOTFILES/common/nvim" "$CONFIG/nvim"

install_git_credential_manager() {
    git config --global include.path "$HOME/.gitconfig.local"

    case "$OS" in
        windows)
            git config --file "$HOME/.gitconfig.local" credential.helper manager-core
            ;;

        wsl)
            git config --file "$HOME/.gitconfig.local" credential.helper "/mnt/c/Program\ Files/Git/mingw64/bin/git-credential-manager.exe"
            ;;

        linux)
            if command -v curl &>/dev/null; then
                if ! command -v git-credential-manager &>/dev/null; then
                    curl -fsSL https://aka.ms/gcm/linux-install-source.sh -o /tmp/gcm-install.sh
                    bash /tmp/gcm-install.sh install
                    rm -f /tmp/gcm-install.sh

                    sudo apt update
                    sudo apt install -y libsecret-1-0 libsecret-1-dev gnome-keyring
                fi

                git config --file "$HOME/.gitconfig.local" credential.helper manager
                git config --file "$HOME/.gitconfig.local" credential.credentialStore secretservice
            else
                echo "⚠️  Curl not found. Please install Git Credential Manager manually:"
                echo "https://aka.ms/gcm/linux"
            fi
            ;;

        mac)
            if command -v brew &>/dev/null; then
                if ! command -v git-credential-manager &>/dev/null; then
                    brew install --cask git-credential-manager
                fi

                git config --file "$HOME/.gitconfig.local" credential.helper manager
            else
                echo "⚠️  Homebrew not found. Please install Git Credential Manager manually:"
                echo "https://aka.ms/gcm/mac"
            fi
            ;;
        *)
    esac
}

case "$OS" in
    linux|wsl|mac|windows)
        install_git_credential_manager
        ;;
    *)
esac

