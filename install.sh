#!/bin/bash
# Install git-yak, git-stack, git-sync as git subcommands
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
COMMANDS=(git-yak git-stack git-sync git-stack-tree git-stack-pr)

# find a writable bin directory on PATH
find_bin_dir() {
    # prefer ~/.local/bin (no sudo needed)
    local local_bin="$HOME/.local/bin"
    if echo "$PATH" | tr ':' '\n' | grep -qx "$local_bin"; then
        mkdir -p "$local_bin"
        echo "$local_bin"
        return
    fi

    # try /usr/local/bin
    if [ -w /usr/local/bin ]; then
        echo "/usr/local/bin"
        return
    fi

    # fall back to creating ~/.local/bin and warn about PATH
    mkdir -p "$local_bin"
    echo "$local_bin"
    echo "" >&2
    echo "Note: $local_bin is not in your PATH." >&2
    echo "Add this to your shell profile (~/.bashrc, ~/.zshrc, etc.):" >&2
    echo "  export PATH=\"$local_bin:\$PATH\"" >&2
}

usage() {
    echo "Usage: $0 [--symlink | --copy] [--bin-dir <dir>]"
    echo ""
    echo "  --symlink   Create symlinks (default, keeps scripts updated with repo)"
    echo "  --copy      Copy scripts (standalone, no dependency on repo location)"
    echo "  --bin-dir   Install to a specific directory instead of auto-detecting"
    echo "  --uninstall Remove installed commands"
}

MODE="symlink"
BIN_DIR=""
UNINSTALL=false

while [ $# -gt 0 ]; do
    case "$1" in
        --symlink)  MODE="symlink"; shift ;;
        --copy)     MODE="copy"; shift ;;
        --bin-dir)  if [ -z "${2:-}" ]; then echo "Error: --bin-dir requires an argument"; exit 1; fi; BIN_DIR="$2"; shift 2 ;;
        --uninstall) UNINSTALL=true; shift ;;
        -h|--help)  usage; exit 0 ;;
        *)          echo "Unknown option: $1"; usage; exit 1 ;;
    esac
done

if [ -z "$BIN_DIR" ]; then
    BIN_DIR=$(find_bin_dir)
fi

if [ "$UNINSTALL" = true ]; then
    for cmd in "${COMMANDS[@]}"; do
        target="$BIN_DIR/$cmd"
        if [ -e "$target" ] || [ -L "$target" ]; then
            rm "$target"
            echo "Removed $target"
        fi
    done
    echo "Uninstalled."
    exit 0
fi

for cmd in "${COMMANDS[@]}"; do
    src="$SCRIPT_DIR/$cmd"
    target="$BIN_DIR/$cmd"

    if [ ! -f "$src" ]; then
        echo "Error: $src not found"
        exit 1
    fi

    if [ "$MODE" = "symlink" ]; then
        ln -sf "$src" "$target"
        echo "Linked $target -> $src"
    else
        cp "$src" "$target"
        chmod +x "$target"
        echo "Copied $src -> $target"
    fi
done

echo ""
echo "Installed. You can now use: git yak, git stack, git sync"
