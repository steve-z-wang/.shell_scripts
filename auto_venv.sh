# Auto-activate Python virtual environments
# Automatically activates venv/.venv when entering a directory that contains one

auto_activate_venv() {
    # Deactivate any currently active virtual environment
    if [[ -n "$VIRTUAL_ENV" ]]; then
        # Check if current venv is still valid for this directory
        local current_dir="$PWD"
        local venv_dir=""

        if [[ -d "$current_dir/venv" ]]; then
            venv_dir="$current_dir/venv"
        elif [[ -d "$current_dir/.venv" ]]; then
            venv_dir="$current_dir/.venv"
        fi

        # If the current VIRTUAL_ENV doesn't match the directory's venv, deactivate
        if [[ -z "$venv_dir" ]] || [[ "$VIRTUAL_ENV" != "$venv_dir" ]]; then
            deactivate 2>/dev/null
        fi
    fi

    # Try to activate venv in current directory
    if [[ -z "$VIRTUAL_ENV" ]]; then
        if [[ -f "$PWD/venv/bin/activate" ]]; then
            source "$PWD/venv/bin/activate"
            echo "✓ Activated venv: $PWD/venv"
        elif [[ -f "$PWD/.venv/bin/activate" ]]; then
            source "$PWD/.venv/bin/activate"
            echo "✓ Activated venv: $PWD/.venv"
        fi
    fi
}

# Hook into directory changes
if ! typeset -f chpwd > /dev/null; then
    chpwd() {
        auto_activate_venv
    }
else
    # Append to existing chpwd function
    chpwd_functions+=(auto_activate_venv)
fi

# Activate on shell startup if in a directory with venv
auto_activate_venv
