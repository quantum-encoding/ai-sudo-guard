#!/bin/bash
# AI Sudo Guard - Deletion Protection Module
# Prevents accidental file deletion by AI agents
# Requires sudo for all deletion operations outside safe zones

# Color codes for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Function to check if running as root
is_root() {
    [ "$EUID" -eq 0 ]
}

# Function to log deletion attempts
log_deletion_attempt() {
    local cmd="$1"
    local args="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] User: $USER | PID: $$ | Command: $cmd | Args: $args" >> "$HOME/.deletion_attempts.log"
}

# Check if path is in an allowed deletion zone (build artifacts, caches, temp)
is_safe_deletion_zone() {
    local path="$1"

    # Convert to absolute path if relative
    if [[ ! "$path" = /* ]]; then
        path="$(pwd)/$path"
    fi

    # Safe patterns - build directories, caches, temp files
    if [[ "$path" =~ ^$HOME/\.cache/yay/ ]] || \
       [[ "$path" =~ ^$HOME/\.cache/paru/ ]] || \
       [[ "$path" =~ ^$HOME/\.cache/makepkg($|/) ]] || \
       [[ "$path" =~ ^$HOME/.*/zig-out($|/) ]] || \
       [[ "$path" =~ ^$HOME/.*/zig-cache($|/) ]] || \
       [[ "$path" =~ ^$HOME/.*/target/debug($|/) ]] || \
       [[ "$path" =~ ^$HOME/.*/target/release($|/) ]] || \
       [[ "$path" =~ ^$HOME/.*/build($|/) ]] || \
       [[ "$path" =~ ^$HOME/.*/.cache($|/) ]] || \
       [[ "$path" =~ ^$HOME/.*/node_modules($|/) ]] || \
       [[ "$path" =~ ^$HOME/.*/__pycache__($|/) ]] || \
       [[ "$path" =~ ^$HOME/.*/.pytest_cache($|/) ]] || \
       [[ "$path" =~ ^$HOME/.*/.mypy_cache($|/) ]] || \
       [[ "$path" =~ ^$HOME/.*/dist($|/) ]] || \
       [[ "$path" =~ ^$HOME/.*/.tox($|/) ]] || \
       [[ "$path" =~ ^$HOME/.*/.venv($|/) ]] || \
       [[ "$path" =~ ^$HOME/.*/.gradle($|/) ]] || \
       [[ "$path" =~ ^$HOME/.*/\.next($|/) ]] || \
       [[ "$path" =~ ^/tmp/ ]] || \
       [[ "$path" =~ ^/var/tmp/ ]]; then
        return 0  # Safe
    fi

    return 1  # Not safe
}

# Check if all arguments are in safe zones
all_args_safe() {
    for arg in "$@"; do
        # Skip flags
        [[ "$arg" == -* ]] && continue

        if ! is_safe_deletion_zone "$arg"; then
            return 1
        fi
    done
    return 0
}

# Override rm command
rm() {
    log_deletion_attempt "rm" "$*"

    if is_root; then
        command rm "$@"
        return $?
    fi

    if all_args_safe "$@" && [ $# -gt 0 ]; then
        command rm "$@"
        return $?
    fi

    echo -e "${RED}DELETION PROTECTION: 'rm' requires sudo${NC}"
    echo -e "${YELLOW}To delete files, use: sudo rm $*${NC}"
    echo -e "${YELLOW}(Build directories like node_modules, target/, .cache are auto-allowed)${NC}"
    return 1
}

# Override mv when moving to dangerous locations
mv() {
    local last_arg="${@: -1}"

    # Check for moves to /dev/* (destructive)
    if [[ "$last_arg" =~ ^/dev/ ]]; then
        log_deletion_attempt "mv" "$*"
        if ! is_root; then
            echo -e "${RED}DELETION PROTECTION: Moving to /dev/* requires sudo${NC}"
            echo -e "${YELLOW}Use: sudo mv $*${NC}"
            return 1
        fi
    fi

    command mv "$@"
}

# Override shred command
shred() {
    log_deletion_attempt "shred" "$*"

    if is_root; then
        command shred "$@"
        return $?
    fi

    echo -e "${RED}DELETION PROTECTION: 'shred' requires sudo${NC}"
    echo -e "${YELLOW}To securely delete files, use: sudo shred $*${NC}"
    return 1
}

# Override unlink command
unlink() {
    log_deletion_attempt "unlink" "$*"

    if is_root; then
        command unlink "$@"
        return $?
    fi

    echo -e "${RED}DELETION PROTECTION: 'unlink' requires sudo${NC}"
    echo -e "${YELLOW}Use: sudo unlink $*${NC}"
    return 1
}

# Override rmdir command
rmdir() {
    log_deletion_attempt "rmdir" "$*"

    if is_root; then
        command rmdir "$@"
        return $?
    fi

    if all_args_safe "$@" && [ $# -gt 0 ]; then
        command rmdir "$@"
        return $?
    fi

    echo -e "${RED}DELETION PROTECTION: 'rmdir' requires sudo${NC}"
    echo -e "${YELLOW}Use: sudo rmdir $*${NC}"
    return 1
}

# Override dd command (for output files)
dd() {
    if [[ "$*" =~ of= ]]; then
        local cwd=$(pwd)
        # Allow in safe build directories
        if [[ "$cwd" =~ ^$HOME/\.cache/ ]] || \
           [[ "$cwd" =~ ^/tmp/ ]] || \
           [[ "$cwd" =~ ^/var/tmp/ ]]; then
            command dd "$@"
            return $?
        fi

        log_deletion_attempt "dd" "$*"
        if ! is_root; then
            echo -e "${RED}DELETION PROTECTION: 'dd' with output file requires sudo${NC}"
            echo -e "${YELLOW}Use: sudo dd $*${NC}"
            return 1
        fi
    fi

    command dd "$@"
}

# Override truncate command
truncate() {
    log_deletion_attempt "truncate" "$*"

    if is_root; then
        command truncate "$@"
        return $?
    fi

    echo -e "${RED}DELETION PROTECTION: 'truncate' requires sudo${NC}"
    echo -e "${YELLOW}Use: sudo truncate $*${NC}"
    return 1
}

# Override find with -delete
find() {
    if [[ "$*" =~ -delete ]]; then
        log_deletion_attempt "find" "$*"
        if ! is_root; then
            echo -e "${RED}DELETION PROTECTION: 'find' with -delete requires sudo${NC}"
            echo -e "${YELLOW}Use: sudo find $*${NC}"
            return 1
        fi
    fi

    command find "$@"
}

# Override xargs with deletion commands
xargs() {
    if [[ "$*" =~ rm ]] || [[ "$*" =~ unlink ]] || [[ "$*" =~ shred ]]; then
        local cwd=$(pwd)
        # Allow in safe build directories
        if [[ "$cwd" =~ ^$HOME/\.cache/ ]] || \
           [[ "$cwd" =~ ^/tmp/ ]] || \
           [[ "$cwd" =~ ^/var/tmp/ ]]; then
            command xargs "$@"
            return $?
        fi

        log_deletion_attempt "xargs" "$*"
        if ! is_root; then
            echo -e "${RED}DELETION PROTECTION: 'xargs' with deletion commands requires sudo${NC}"
            echo -e "${YELLOW}Use: sudo xargs $*${NC}"
            return 1
        fi
    fi

    command xargs "$@"
}

# Emergency bypass (requires explicit confirmation)
unsafe_rm() {
    echo -e "${RED}WARNING: Bypassing deletion protection${NC}"
    echo -e "${YELLOW}This removes AI agent protection!${NC}"
    read -p "Type 'I UNDERSTAND THE RISKS' to proceed: " confirmation

    if [[ "$confirmation" == "I UNDERSTAND THE RISKS" ]]; then
        echo -e "${GREEN}Executing unprotected deletion...${NC}"
        command rm "$@"
    else
        echo -e "${RED}Aborted. Use 'sudo rm' for protected deletion.${NC}"
        return 1
    fi
}

# Show protection status
show_deletion_protection_status() {
    echo -e "${GREEN}File Deletion Protection Status${NC}"
    echo -e "========================================"
    echo -e "${GREEN}[OK]${NC} rm command: Protected (requires sudo)"
    echo -e "${GREEN}[OK]${NC} mv to /dev/*: Protected (requires sudo)"
    echo -e "${GREEN}[OK]${NC} shred command: Protected (requires sudo)"
    echo -e "${GREEN}[OK]${NC} unlink command: Protected (requires sudo)"
    echo -e "${GREEN}[OK]${NC} rmdir command: Protected (requires sudo)"
    echo -e "${GREEN}[OK]${NC} dd command: Protected for output files"
    echo -e "${GREEN}[OK]${NC} truncate command: Protected (requires sudo)"
    echo -e "${GREEN}[OK]${NC} find -delete: Protected (requires sudo)"
    echo -e "${GREEN}[OK]${NC} xargs deletion: Protected (requires sudo)"
    echo -e "${GREEN}[OK]${NC} Deletion logging: ~/.deletion_attempts.log"
    echo ""
    echo -e "${YELLOW}To delete files: sudo rm <file>${NC}"
    echo -e "${YELLOW}To bypass (dangerous): unsafe_rm <file>${NC}"
}

# Export functions for subshells
export -f is_root is_safe_deletion_zone all_args_safe log_deletion_attempt
export -f rm mv shred unlink rmdir dd truncate find xargs
export -f unsafe_rm show_deletion_protection_status

# Startup message (can be commented out)
echo -e "${GREEN}File deletion protection enabled${NC} (run 'show_deletion_protection_status' for details)"
