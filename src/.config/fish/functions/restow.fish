function restow
    if test -z "$DOTFILES_ROOT"
        echo "\$DOTFILES_ROOT is not set"
        return
    end
    set _dir "$(pwd)"
    cd $DOTFILES_ROOT && stow --target $HOME src
    cd $_dir

    # rebuild bat cache for theme updates
    if command -q bat
        if bat cache --build >/dev/null 2>&1
            echo "Rebuilt bat cache successfully"
        else
            echo "Failed to rebuild bat cache"
        end
    end

    rf
end
