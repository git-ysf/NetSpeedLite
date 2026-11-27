#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
cd "$SCRIPT_DIR"

USER_INSTALL=0
PREFIX="/usr/local"

for arg in "$@"; do
    case "$arg" in
        --user)
            USER_INSTALL=1
            PREFIX="$HOME/.local"
            ;;
        -h|--help)
            cat <<EOF
NetSpeedLite Linux Installer

Usage: ./install.sh [--user]
  --user    Install to ~/.local/bin and ~/.local/share/applications (no sudo)
EOF
            exit 0
            ;;
        *)
            echo "Unknown option: $arg" >&2
            exit 1
            ;;
    esac
done

if ! command -v gcc >/dev/null 2>&1 && ! command -v clang >/dev/null 2>&1; then
    echo "Error: gcc or clang is required to build NetSpeedLite." >&2
    exit 1
fi

CC_BIN="${CC:-}"
if [ -z "$CC_BIN" ]; then
    if command -v gcc >/dev/null 2>&1; then
        CC_BIN="gcc"
    else
        CC_BIN="clang"
    fi
fi

echo "Building NetSpeedLite with $CC_BIN..."
make CC="$CC_BIN" clean all

echo "Installing to $PREFIX..."
if [ "$USER_INSTALL" -eq 1 ] || [ "$(id -u)" -eq 0 ]; then
    make PREFIX="$PREFIX" install
else
    sudo make PREFIX="$PREFIX" install
fi

echo ""
echo "Installed: $PREFIX/bin/netspeedlite"
echo "Run 'netspeedlite --tui' for live terminal monitor, or 'netspeedlite --waybar' for Waybar."
