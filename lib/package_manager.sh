prepare_package_manager() {
    case "$OS" in
        linux|wsl)
            case "$DISTRO" in
                ubuntu|debian)
                    sudo apt-get update
                    ;;

                fedora|arch)
                    return 0 
                    ;;

                *)
                    return 1
                    ;;
            esac
            ;;

        windows|mac)
            return 0 
            ;;

        *)
            return 1
            ;;
    esac
}
