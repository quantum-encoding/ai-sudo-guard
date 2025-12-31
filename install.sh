#!/bin/bash
# AI Sudo Guard - Installation Script

set -e

INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}AI Sudo Guard - Installation${NC}"
echo "=============================="
echo ""

# Check for GUI dialog tool
if ! command -v zenity &> /dev/null && ! command -v kdialog &> /dev/null; then
    echo -e "${YELLOW}Warning: No GUI dialog tool found.${NC}"
    echo "Install zenity (GNOME/GTK) or kdialog (KDE/Qt) for GUI dialogs."
    echo ""
    echo "  Arch/Manjaro:  sudo pacman -S zenity"
    echo "  Ubuntu/Debian: sudo apt install zenity"
    echo "  Fedora:        sudo dnf install zenity"
    echo ""
fi

# Check for chattr (needed for immutable protection)
if ! command -v chattr &> /dev/null; then
    echo -e "${YELLOW}Warning: chattr not found. Immutable protection won't work.${NC}"
    echo "Install e2fsprogs if you want file locking."
    echo ""
fi

# Create install directory if needed
mkdir -p "$INSTALL_DIR"

# Check if ~/.local/bin is in PATH
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    echo -e "${YELLOW}Warning: $HOME/.local/bin is not in your PATH${NC}"
    echo ""
    echo "Add this to your ~/.bashrc or ~/.zshrc:"
    echo ""
    echo '  export PATH="$HOME/.local/bin:$PATH"'
    echo ""
fi

#
# Install sudo wrapper
#
echo -e "${BLUE}[1/4] Sudo Approval Wrapper${NC}"
if [[ -f "$INSTALL_DIR/sudo" ]]; then
    # Check if immutable
    if lsattr "$INSTALL_DIR/sudo" 2>/dev/null | grep -q "i"; then
        echo -e "${YELLOW}Existing sudo wrapper is locked (immutable).${NC}"
        echo "Run 'guard-lock unlock' first, then re-run installer."
        exit 1
    fi

    echo -e "${YELLOW}Existing sudo wrapper found.${NC}"
    read -p "Overwrite? [y/N]: " response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo "Skipping sudo wrapper."
    else
        cp "$SCRIPT_DIR/sudo" "$INSTALL_DIR/sudo"
        chmod +x "$INSTALL_DIR/sudo"
        echo -e "${GREEN}Sudo wrapper installed.${NC}"
    fi
else
    cp "$SCRIPT_DIR/sudo" "$INSTALL_DIR/sudo"
    chmod +x "$INSTALL_DIR/sudo"
    echo -e "${GREEN}Sudo wrapper installed.${NC}"
fi

# Install askpass helper
cp "$SCRIPT_DIR/sudo-askpass-gui" "$INSTALL_DIR/sudo-askpass-gui"
chmod +x "$INSTALL_DIR/sudo-askpass-gui"
echo -e "${GREEN}Sudo askpass helper installed.${NC}"
echo ""

#
# Install guard-lock utility
#
echo -e "${BLUE}[2/4] Guard Lock Utility${NC}"
cp "$SCRIPT_DIR/guard-lock" "$INSTALL_DIR/guard-lock"
chmod +x "$INSTALL_DIR/guard-lock"
echo -e "${GREEN}Guard lock utility installed.${NC}"
echo ""

#
# Install deletion protection
#
echo -e "${BLUE}[3/4] Deletion Protection Module${NC}"
echo "Intercepts rm, shred, dd, etc. to require sudo."
echo "Build artifacts (node_modules, target/, .cache) are auto-allowed."
echo ""
read -p "Install deletion protection? [Y/n]: " install_deletion

if [[ ! "$install_deletion" =~ ^[Nn]$ ]]; then
    DELETION_SCRIPT="$HOME/.bash_deletion_protection.sh"

    if [[ -f "$DELETION_SCRIPT" ]]; then
        if lsattr "$DELETION_SCRIPT" 2>/dev/null | grep -q "i"; then
            echo -e "${YELLOW}Existing file is locked. Run 'guard-lock unlock' first.${NC}"
        else
            read -p "Overwrite existing deletion protection? [y/N]: " response
            if [[ "$response" =~ ^[Yy]$ ]]; then
                cp "$SCRIPT_DIR/deletion-protection.sh" "$DELETION_SCRIPT"
                echo -e "${GREEN}Deletion protection installed.${NC}"
            fi
        fi
    else
        cp "$SCRIPT_DIR/deletion-protection.sh" "$DELETION_SCRIPT"
        echo -e "${GREEN}Deletion protection installed.${NC}"
    fi

    # Add to bashrc if not already present
    if ! grep -q "bash_deletion_protection" "$HOME/.bashrc" 2>/dev/null; then
        echo "" >> "$HOME/.bashrc"
        echo "# AI Sudo Guard - Deletion Protection" >> "$HOME/.bashrc"
        echo "[ -f ~/.bash_deletion_protection.sh ] && source ~/.bash_deletion_protection.sh" >> "$HOME/.bashrc"
        echo -e "${GREEN}Added to ~/.bashrc${NC}"
    fi

    # Add to zshrc if it exists
    if [[ -f "$HOME/.zshrc" ]]; then
        if ! grep -q "bash_deletion_protection" "$HOME/.zshrc" 2>/dev/null; then
            echo "" >> "$HOME/.zshrc"
            echo "# AI Sudo Guard - Deletion Protection" >> "$HOME/.zshrc"
            echo "[ -f ~/.bash_deletion_protection.sh ] && source ~/.bash_deletion_protection.sh" >> "$HOME/.zshrc"
            echo -e "${GREEN}Added to ~/.zshrc${NC}"
        fi
    fi
fi
echo ""

#
# Install integrity check
#
echo -e "${BLUE}[4/4] Startup Integrity Check${NC}"
echo "Verifies guard files haven't been tampered with on each shell start."
echo ""
read -p "Install integrity check? [Y/n]: " install_integrity

if [[ ! "$install_integrity" =~ ^[Nn]$ ]]; then
    INTEGRITY_SCRIPT="$HOME/.ai_sudo_guard_integrity.sh"
    cp "$SCRIPT_DIR/integrity-check.sh" "$INTEGRITY_SCRIPT"

    # Add to bashrc if not already present
    if ! grep -q "ai_sudo_guard_integrity" "$HOME/.bashrc" 2>/dev/null; then
        echo "" >> "$HOME/.bashrc"
        echo "# AI Sudo Guard - Integrity Check" >> "$HOME/.bashrc"
        echo "[ -f ~/.ai_sudo_guard_integrity.sh ] && source ~/.ai_sudo_guard_integrity.sh" >> "$HOME/.bashrc"
        echo -e "${GREEN}Integrity check added to ~/.bashrc${NC}"
    fi

    if [[ -f "$HOME/.zshrc" ]]; then
        if ! grep -q "ai_sudo_guard_integrity" "$HOME/.zshrc" 2>/dev/null; then
            echo "" >> "$HOME/.zshrc"
            echo "# AI Sudo Guard - Integrity Check" >> "$HOME/.zshrc"
            echo "[ -f ~/.ai_sudo_guard_integrity.sh ] && source ~/.ai_sudo_guard_integrity.sh" >> "$HOME/.zshrc"
        fi
    fi
fi
echo ""

#
# Summary
#
echo -e "${GREEN}==============================${NC}"
echo -e "${GREEN}Installation complete!${NC}"
echo -e "${GREEN}==============================${NC}"
echo ""
echo "Components installed:"
echo "  - Sudo wrapper:        $INSTALL_DIR/sudo"
echo "  - Askpass helper:      $INSTALL_DIR/sudo-askpass-gui"
echo "  - Guard lock utility:  $INSTALL_DIR/guard-lock"
if [[ ! "$install_deletion" =~ ^[Nn]$ ]]; then
    echo "  - Deletion protection: ~/.bash_deletion_protection.sh"
fi
if [[ ! "$install_integrity" =~ ^[Nn]$ ]]; then
    echo "  - Integrity check:     ~/.ai_sudo_guard_integrity.sh"
fi
echo ""
echo -e "${YELLOW}IMPORTANT: Lock your installation to prevent tampering:${NC}"
echo ""
echo "  guard-lock lock"
echo ""
echo "This sets the immutable flag (requires sudo once) so attackers"
echo "cannot overwrite the sudo wrapper to steal your password."
echo ""
echo "Other commands:"
echo "  guard-lock status   - Show protection status"
echo "  guard-lock verify   - Check file integrity"
echo "  guard-lock unlock   - Unlock for updates (requires sudo)"
echo ""
echo -e "${YELLOW}Restart your terminal or run: source ~/.bashrc${NC}"
echo ""
echo "To uninstall:"
echo "  guard-lock unlock"
echo "  rm $INSTALL_DIR/sudo $INSTALL_DIR/sudo-askpass-gui $INSTALL_DIR/guard-lock"
echo "  rm ~/.bash_deletion_protection.sh ~/.ai_sudo_guard_integrity.sh ~/.ai_sudo_guard.sha256"
echo "  # Remove the source lines from ~/.bashrc"
