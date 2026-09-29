setup_shared() {
    run_setup ".NET SDK" setup_dotnet || :
    run_setup "Git" setup_git || :
    run_setup "Git Credential Manager" setup_git_credential_manager || :
    run_setup "Neovim" setup_nvim || :
}
