# Enhanced multidir function with better tab completion support
multidir() {
    local directories=()
    local parent_dir=""
    local recursive=false
    local command=()
    local dry_run=false
    local verbose=false
    local filter=""

    _multidir_show_help() {
        cat << 'EOF'
Usage: multidir [OPTIONS] -- COMMAND

Run a command in multiple directories

Options:
  -d, --dir DIRECTORY         Add a directory (can be used multiple times)
  -p, --parent PARENT_DIR     Use all subdirectories of PARENT_DIR
  -r, --recursive             Include subdirectories recursively (with -p)
  -f, --filter PATTERN        Filter directories by pattern (with -p)
  -n, --dry-run               Show what would be executed without running
  -v, --verbose               Show additional information
  -h, --help                  Show this help

Examples:
  multidir -d ../project1 -d ../project2 -- git status
  multidir -d ~/app -d ~/api -d ~/frontend -- npm test
  multidir -p /projects -- npm install
  multidir -p /projects -r -f "*react*" -- npm test
  multidir -p /workspace -n -- git pull

Note: You can also use comma-separated dirs: -d "dir1,dir2,dir3"
EOF
    }

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--dir)
                if [[ -z "$2" ]]; then
                    echo "❌ Error: -d/--dir requires an argument"
                    return 1
                fi

                # Check if it contains commas (backward compatibility)
                if [[ "$2" == *","* ]]; then
                    IFS=',' read -ra ADDR <<< "$2"
                    for i in "${ADDR[@]}"; do
                        directories+=("$(echo "$i" | xargs)")
                    done
                else
                    # Single directory
                    directories+=("$2")
                fi
                shift 2
                ;;
            -p|--parent)
                if [[ -z "$2" ]]; then
                    echo "❌ Error: -p/--parent requires an argument"
                    return 1
                fi
                parent_dir="$2"
                shift 2
                ;;
            -r|--recursive)
                recursive=true
                shift
                ;;
            -f|--filter)
                if [[ -z "$2" ]]; then
                    echo "❌ Error: -f/--filter requires a pattern"
                    return 1
                fi
                filter="$2"
                shift 2
                ;;
            -n|--dry-run)
                dry_run=true
                shift
                ;;
            -v|--verbose)
                verbose=true
                shift
                ;;
            -h|--help)
                _multidir_show_help
                return 0
                ;;
            --)
                shift
                command=("$@")
                break
                ;;
            *)
                echo "❌ Unknown option: $1"
                _multidir_show_help
                return 1
                ;;
        esac
    done

    # Validate input
    if [[ ${#command[@]} -eq 0 ]]; then
        echo "❌ Error: No command specified"
        _multidir_show_help
        return 1
    fi

    # Build directory list from parent directory
    if [[ -n "$parent_dir" ]]; then
        if [[ ! -d "$parent_dir" ]]; then
            echo "❌ Error: Parent directory '$parent_dir' does not exist"
            return 1
        fi

        if [[ "$recursive" == true ]]; then
            while IFS= read -r -d '' dir; do
                if [[ -z "$filter" || "$dir" == *$filter* ]]; then
                    directories+=("$dir")
                fi
            done < <(find "$parent_dir" -type d -print0 2>/dev/null)
        else
            for dir in "$parent_dir"/*/; do
                if [[ -d "$dir" ]]; then
                    dir="${dir%/}"
                    if [[ -z "$filter" || "$dir" == *$filter* ]]; then
                        directories+=("$dir")
                    fi
                fi
            done
        fi
    fi

    # Validate directories
    if [[ ${#directories[@]} -eq 0 ]]; then
        echo "❌ Error: No directories specified or found"
        return 1
    fi

    # Remove duplicates, resolve paths, and sort
    local resolved_dirs=()
    for dir in "${directories[@]}"; do
        if [[ -d "$dir" ]]; then
            # Resolve to absolute path to avoid duplicates
            resolved_dir=$(cd "$dir" 2>/dev/null && pwd)
            [[ -n "$resolved_dir" ]] && resolved_dirs+=("$resolved_dir")
        else
            echo "⚠️  Warning: Directory '$dir' does not exist"
        fi
    done

    # Remove duplicates and sort
    local unique_dirs=($(printf '%s\n' "${resolved_dirs[@]}" | sort -u))
    directories=("${unique_dirs[@]}")

    # Show what will be executed
    echo "🚀 Command: ${command[*]}"
    echo "📂 Directories (${#directories[@]}):"
    if [[ "$verbose" == true ]]; then
        printf '  %s\n' "${directories[@]}"
    else
        # Show first few directories
        local display_count=3
        for ((i=0; i<${#directories[@]} && i<display_count; i++)); do
            printf '  %s\n' "${directories[i]}"
        done
        if [[ ${#directories[@]} -gt $display_count ]]; then
            echo "  ... and $((${#directories[@]} - display_count)) more"
        fi
    fi

    if [[ "$dry_run" == true ]]; then
        echo "🔍 Dry run - no commands will be executed"
        return 0
    fi

    echo "$(printf '=%.0s' {1..50})"

    # Store current directory and execution stats
    local original_dir=$(pwd)
    local success_count=0
    local error_count=0

    # Execute command in each directory
    for dir in "${directories[@]}"; do
        echo ""
        echo "📁 Directory: $dir"
        echo "$(printf -- '-%.0s' {1..30})"

        if cd "$dir" 2>/dev/null; then
            if "${command[@]}"; then
                echo "✅ Success"
                ((success_count++))
            else
                local exit_code=$?
                echo "❌ Command failed (exit code: $exit_code)"
                ((error_count++))
            fi
        else
            echo "❌ Cannot access directory: $dir"
            ((error_count++))
        fi
    done

    # Restore original directory
    cd "$original_dir" 2>/dev/null

    # Show summary
    echo ""
    echo "$(printf '=%.0s' {1..50})"
    echo "📊 Summary: $success_count successful, $error_count failed"

    # Return appropriate exit code
    if [[ $error_count -gt 0 ]]; then
        return 1
    else
        return 0
    fi
}

# Enhanced zsh completion
if [[ -n "$ZSH_VERSION" ]]; then
    _multidir() {
        local context state line
        local -a arguments

        arguments=(
            '(-d --dir)'{-d,--dir}'[Add directory]:directory:_directories'
            '(-p --parent)'{-p,--parent}'[Parent directory]:parent directory:_directories'
            '(-r --recursive)'{-r,--recursive}'[Include subdirectories recursively]'
            '(-f --filter)'{-f,--filter}'[Filter directories by pattern]:pattern:'
            '(-n --dry-run)'{-n,--dry-run}'[Show what would be executed without running]'
            '(-v --verbose)'{-v,--verbose}'[Show additional information]'
            '(-h --help)'{-h,--help}'[Show help]'
            '*::command:_command_names'
        )

        _arguments -s $arguments
    }

    compdef _multidir multidir
fi
