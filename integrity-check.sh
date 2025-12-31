#!/bin/bash
# AI Sudo Guard - Startup Integrity Check
# Source this from .bashrc to verify guard files haven't been tampered with

_ai_sudo_guard_check() {
    local HASH_FILE="$HOME/.ai_sudo_guard.sha256"

    # Skip if no hash file (not locked yet)
    [[ ! -f "$HASH_FILE" ]] && return 0

    # Silent verification
    if ! sha256sum -c "$HASH_FILE" --status 2>/dev/null; then
        echo -e "\033[0;31m"
        echo "=================================================="
        echo "  WARNING: AI SUDO GUARD INTEGRITY CHECK FAILED"
        echo "=================================================="
        echo -e "\033[0m"
        echo "Guard files may have been tampered with!"
        echo ""
        echo "Run 'guard-lock verify' for details, or"
        echo "Run 'guard-lock lock' to re-secure after reviewing changes."
        echo ""
        # Don't block shell startup, just warn
    fi
}

# Run check on shell startup (non-blocking)
_ai_sudo_guard_check
