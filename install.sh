#!/bin/bash

# The git alias definition
ALIAS_DEFINITION='!f() {
    # Check for continue flag first
    if [ "$1" = "-continue" ]; then
        git rebase --continue
        return
    fi

    # Check if we are in the middle of a rebase
    if [ -d "$(git rev-parse --git-dir)/rebase-merge" ] || [ -d "$(git rev-parse --git-dir)/rebase-apply" ]; then
        # If we get -t or -o during a rebase conflict, abort and restart with that strategy
        if [ "$1" = "-t" ] || [ "$1" = "-o" ]; then
            echo "Conflict detected. Aborting current rebase and restarting with $1 strategy..."
            git rebase --abort

            # Store current branch for reuse
            current_branch=$(git rev-parse --abbrev-ref HEAD)

            # Convert -t/-o to full strategy option
            if [ "$1" = "-t" ]; then
                git rebase --strategy-option=theirs origin/$current_branch
            else
                git rebase --strategy-option=ours origin/$current_branch
            fi
            return
        fi
    fi

    remote="origin"
    force=false
    branch=""
    strategy=""

    # Parse options
    while getopts "fr:t:o" opt; do
        case $opt in
            f) force=true ;;
            r) remote=$OPTARG ;;
            t) strategy="--strategy-option=theirs" ;;
            o) strategy="--strategy-option=ours" ;;
            \?) echo "Invalid option: -$OPTARG" >&2; return 1 ;;
        esac
    done

    # Shift past the options
    shift $((OPTIND-1))

    # Get branch name from argument or current branch
    if [ -n "$1" ]; then
        branch=$1
    else
        branch=$(git rev-parse --abbrev-ref HEAD)
    fi

    # Fetch from specified remote
    git fetch $remote

    # Perform sync based on force flag
    if [ "$force" = true ]; then
        git reset --hard $remote/$branch
    else
        if [ -n "$strategy" ]; then
            git rebase $strategy $remote/$branch
        else
            git rebase $remote/$branch
        fi
    fi
}; f'

# Function to add the alias to git config
install_git_alias() {
    # Escape single quotes in the alias definition
    ESCAPED_ALIAS=$(echo "$ALIAS_DEFINITION" | sed "s/'/'\\\\''/g")
    
    # Add the alias to git config
    git config --global alias.sync "$ESCAPED_ALIAS"
    
    echo "Git sync alias has been installed successfully!"
    echo "You can now use 'git sync' with the following options:"
    echo "  git sync                     # Basic rebase (current branch)"
    echo "  git sync feature-branch      # Basic rebase (specific branch)"
    echo "  git sync -f                  # Force reset"
    echo "  git sync -f feature-branch   # Force reset (specific branch)"
    echo "  git sync -r upstream         # Different remote"
    echo "  git sync -t                  # Auto-resolve conflicts favoring their changes"
    echo "  git sync -o                  # Auto-resolve conflicts favoring our changes"
}

# Run the installation
install_git_alias

