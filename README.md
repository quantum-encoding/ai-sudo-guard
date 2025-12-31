# AI Sudo Guard

Protect your system from accidental damage by AI coding assistants.

## The Problem

AI coding assistants (Claude Code, Google Gemini, GitHub Copilot, Cursor, etc.) can execute shell commands. Sometimes they request dangerous operations:

- AI misunderstands a request and runs `rm -rf /`
- AI hallucinates a "cleanup" solution involving `dd if=/dev/zero`
- AI attempts to "fix" permissions with `chmod -R 777 /`
- AI runs destructive commands without understanding the context

**Real incidents have occurred** where AI assistants wiped drives or corrupted systems.

## The Solution

AI Sudo Guard provides three layers of protection:

### Layer 1: Sudo Approval Dialog
Intercepts all `sudo` commands and shows a GUI dialog before executing:

```
+------------------------------------------------------------------+
|  AI SUDO GUARD - APPROVAL REQUIRED                               |
+------------------------------------------------------------------+

An AI assistant is requesting sudo privileges:

sudo rm -rf /important/data

Do you approve this command? [y/N]:
```

### Layer 2: Deletion Protection
Intercepts destructive commands (`rm`, `shred`, `dd`, etc.) and requires `sudo`:

```
DELETION PROTECTION: 'rm' requires sudo
To delete files, use: sudo rm myfile.txt
(Build directories like node_modules, target/, .cache are auto-allowed)
```

### Layer 3: Tamper Protection
Prevents attackers from replacing the guard with a malicious version:

```bash
$ guard-lock status
AI Sudo Guard - Protection Status
===================================
[LOCKED]   /home/user/.local/bin/sudo
[LOCKED]   /home/user/.local/bin/sudo-askpass-gui
Integrity: OK
```

## Installation

```bash
git clone https://github.com/YOUR_USERNAME/ai-sudo-guard.git
cd ai-sudo-guard
./install.sh
```

After installation, **lock your files**:

```bash
guard-lock lock
```

This is critical - it prevents attackers from replacing the sudo wrapper with a password stealer.

### Dependencies

For GUI dialogs (recommended):
- **zenity** (GNOME/GTK): `sudo pacman -S zenity` / `sudo apt install zenity`
- **kdialog** (KDE/Qt): `sudo pacman -S kdialog` / `sudo apt install kdialog`

For tamper protection:
- **e2fsprogs** (provides `chattr`): Usually pre-installed on Linux

## How It Works

### Sudo Protection (PATH Hijacking)
1. Wrapper installed to `~/.local/bin/sudo` shadows `/usr/bin/sudo`
2. When AI runs `sudo <cmd>`, wrapper shows approval dialog
3. Only after approval does it call the real sudo with password prompt
4. All requests logged to `~/.ai_sudo_requests.log`

### Deletion Protection
1. Shell functions override `rm`, `shred`, `dd`, `truncate`, etc.
2. Commands blocked unless running as root (via sudo)
3. Build artifacts auto-allowed (node_modules, target/, .cache, /tmp)
4. All attempts logged to `~/.deletion_attempts.log`

### Tamper Protection
1. `guard-lock lock` generates SHA256 hashes and sets immutable flag
2. Immutable files cannot be modified, even by root, until unlocked
3. On each shell startup, integrity check verifies hashes
4. If tampering detected, warning displayed immediately

**Why this works:** An attacker trying to replace `~/.local/bin/sudo` with a malicious version would need sudo to run `chattr -i`. But to get sudo, they'd have to go through our wrapper, which requires your approval. Catch-22 for the attacker.

## Guard Lock Commands

```bash
guard-lock lock      # Hash files and set immutable flag (requires sudo once)
guard-lock unlock    # Remove immutable flag for updates (requires sudo)
guard-lock verify    # Check file integrity against saved hashes
guard-lock status    # Show current protection status
```

### Updating After Locking

```bash
guard-lock unlock           # Remove protection temporarily
./install.sh                # Re-run installer or edit files
guard-lock lock             # Re-enable protection
```

## Protected Commands

| Command | Protection |
|---------|------------|
| `rm` | Requires sudo (build dirs exempt) |
| `rmdir` | Requires sudo (build dirs exempt) |
| `shred` | Always requires sudo |
| `unlink` | Always requires sudo |
| `truncate` | Always requires sudo |
| `dd of=*` | Requires sudo for output files |
| `mv` to `/dev/*` | Requires sudo |
| `find -delete` | Requires sudo |
| `xargs rm/shred` | Requires sudo |

## Safe Zones (Auto-Allowed)

Deletion is allowed without sudo in these directories:
- `~/.cache/yay/`, `~/.cache/paru/` (AUR build caches)
- `*/node_modules/` (npm packages)
- `*/target/debug/`, `*/target/release/` (Rust build artifacts)
- `*/zig-out/`, `*/zig-cache/` (Zig build artifacts)
- `*/.venv/`, `*/.tox/` (Python virtual environments)
- `*/__pycache__/`, `*/.pytest_cache/` (Python caches)
- `*/build/`, `*/dist/` (Generic build outputs)
- `/tmp/`, `/var/tmp/` (System temp directories)

## Security Considerations

### What This Protects Against
- AI assistants accidentally running destructive commands
- AI assistants being tricked into running malicious commands
- Basic PATH hijacking attacks (when locked)
- Password theft via fake sudo (when locked)

### What This Does NOT Protect Against
- Direct calls to `/usr/bin/sudo` or `/usr/bin/rm`
- Attacks with existing root access
- AI running in containers/sandboxes with different PATH
- Kernel-level attacks

For comprehensive protection, consider kernel-level solutions using LD_PRELOAD.

## Bypass Options

### For legitimate sudo commands
Approve the dialog - review the command first.

### For legitimate deletions
```bash
sudo rm myfile.txt  # Triggers approval dialog, then works
```

### Emergency bypass
```bash
unsafe_rm myfile.txt  # Requires typing "I UNDERSTAND THE RISKS"
```

## Uninstallation

```bash
guard-lock unlock
rm ~/.local/bin/sudo ~/.local/bin/sudo-askpass-gui ~/.local/bin/guard-lock
rm ~/.bash_deletion_protection.sh ~/.ai_sudo_guard_integrity.sh ~/.ai_sudo_guard.sha256
# Remove the source lines from ~/.bashrc and ~/.zshrc
```

## Files Installed

| File | Purpose |
|------|---------|
| `~/.local/bin/sudo` | Sudo wrapper with approval dialog |
| `~/.local/bin/sudo-askpass-gui` | GUI password prompt helper |
| `~/.local/bin/guard-lock` | Lock/unlock utility |
| `~/.bash_deletion_protection.sh` | Deletion command overrides |
| `~/.ai_sudo_guard_integrity.sh` | Startup integrity check |
| `~/.ai_sudo_guard.sha256` | Hash file for verification |
| `~/.ai_sudo_requests.log` | Log of sudo attempts |
| `~/.deletion_attempts.log` | Log of deletion attempts |

## License

MIT License - Use freely, modify as needed, no warranty.

## Why This Exists

After reports of AI assistants accidentally wiping drives, this provides a simple safety net. The deletion protection layer catches AI "cleanup" attempts, and the tamper protection ensures attackers can't weaponize the same PATH hijacking technique against you.

Stay safe.
