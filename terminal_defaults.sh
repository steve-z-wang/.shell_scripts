# Terminal default behaviors

# Kitty directory tracking - restore last directory on new terminal
if [[ "$TERM" == "xterm-kitty" ]]; then
    # Save current directory on every directory change
    kitty_save_cwd() {
        echo "$PWD" > /tmp/kitty_cwd
    }

    # Add to chpwd hooks if it exists, otherwise create it
    if ! typeset -f chpwd > /dev/null; then
        chpwd() {
            kitty_save_cwd
        }
    else
        # Append to existing chpwd function
        chpwd_functions+=(kitty_save_cwd)
    fi

    # Restore last directory on terminal startup
    if [[ -f /tmp/kitty_cwd ]]; then
        cd "$(cat /tmp/kitty_cwd)" 2>/dev/null
    fi
fi
