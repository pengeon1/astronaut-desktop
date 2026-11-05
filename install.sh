#!/usr/bin/env bash
# ===================================================================
#  🌌 Astronaut Desktop - Automated Turnkey Installer
#  Transforms Ubuntu (GNOME) into a sleek dark minimalist workstation
# ===================================================================
set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="full"

for arg in "$@"; do
    case "$arg" in
        --conky-only) MODE="conky" ;;
        --full) MODE="full" ;;
        -h|--help)
            echo "Usage: ./install.sh [OPTION]"
            echo "Options:"
            echo "  --full        Install complete desktop (Conky, fonts, theme, wallpaper, dock settings) [Default]"
            echo "  --conky-only  Install only Conky widget, fonts, and autostart"
            echo "  -h, --help    Display this help message"
            exit 0
            ;;
    esac
done

echo ""
echo "======================================================"
echo "  🌌 Astronaut Desktop Installation ($MODE mode)"
echo "======================================================"
echo ""

# 1. Install System Dependencies
echo "[1/6] Checking & installing system dependencies..."
DEPS=("conky-all" "gnome-shell-extensions" "dconf-cli" "playerctl" "python3-pil" "curl" "jq")
MISSING_DEPS=()

for dep in "${DEPS[@]}"; do
    if ! dpkg -s "$dep" >/dev/null 2>&1; then
        MISSING_DEPS+=("$dep")
    fi
done

if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    echo "  -> Installing missing packages: ${MISSING_DEPS[*]}"
    sudo apt update -qq
    sudo apt install -y -qq "${MISSING_DEPS[@]}"
else
    echo "  -> All core dependencies already installed."
fi

# 2. Install Custom Fonts
echo "[2/6] Installing custom fonts (Dot Matrix & Rubik)..."
FONT_DIR="$HOME/.local/share/fonts"
mkdir -p "$FONT_DIR"
cp "$REPO_DIR"/fonts/*.ttf "$FONT_DIR/"
fc-cache -f "$FONT_DIR" >/dev/null 2>&1
echo "  -> Fonts installed and cache updated."

# 3. Install Conky Configuration
echo "[3/6] Installing Astronaut Conky suite..."
CONKY_DEST="$HOME/.config/conky/Astronaut"
mkdir -p "$CONKY_DEST/lib" "$CONKY_DEST/scripts"

cp "$REPO_DIR/conky/Astronaut.conf" "$CONKY_DEST/"
cp "$REPO_DIR/conky/lib/rings.lua" "$CONKY_DEST/lib/"
cp "$REPO_DIR"/conky/scripts/* "$CONKY_DEST/scripts/"
cp "$REPO_DIR/conky/start.sh" "$CONKY_DEST/"

chmod +x "$CONKY_DEST/start.sh"
chmod +x "$CONKY_DEST"/scripts/*

# Autostart configuration
AUTOSTART_DIR="$HOME/.config/autostart"
mkdir -p "$AUTOSTART_DIR"
cp "$REPO_DIR/autostart/conky-astronaut.desktop" "$AUTOSTART_DIR/"
echo "  -> Conky configuration and autostart installed."

if [ "$MODE" = "full" ]; then
    # 4. Install Wallpaper
    echo "[4/6] Installing desktop wallpaper..."
    WP_DIR="$HOME/Pictures/Wallpapers"
    mkdir -p "$WP_DIR"
    cp "$REPO_DIR/wallpaper/astronaut-jellyfish.jpg" "$WP_DIR/"
    echo "  -> Wallpaper saved to $WP_DIR/astronaut-jellyfish.jpg"

    # 5. Install & Patch Orchis Theme
    echo "[5/6] Setting up Orchis-Dark theme with custom GNOME Shell tweaks..."
    THEME_DIR="$HOME/.themes/Orchis-Dark"
    if [ ! -d "$THEME_DIR" ]; then
        echo "  -> Orchis theme not found. Installing Orchis-Dark..."
        TEMP_CLONE=$(mktemp -d)
        git clone --depth=1 https://github.com/vinceliuice/Orchis-theme.git "$TEMP_CLONE" >/dev/null 2>&1
        "$TEMP_CLONE/install.sh" -d "$HOME/.themes" -c dark -t default --round >/dev/null 2>&1
        rm -rf "$TEMP_CLONE"
    fi

    # Apply our custom patched GNOME Shell styles (Floating island pills + vertical dock fix)
    mkdir -p "$THEME_DIR/gnome-shell"
    cp -r "$REPO_DIR/theme/gnome-shell/"* "$THEME_DIR/gnome-shell/"
    echo "  -> Custom GNOME Shell styling applied."

    # 6. Apply GNOME & Dock Settings
    echo "[6/6] Applying GNOME preferences (Dock on Right, Yaru-blue-dark, Dark mode)..."
    bash "$REPO_DIR/settings/apply-gnome-settings.sh"
fi

# Start Conky
echo ""
echo "Launching Conky..."
"$CONKY_DEST/start.sh"

echo ""
echo "======================================================"
echo "  ✨ Astronaut Desktop setup complete!"
echo "  Enjoy your sleek, modern dark environment."
echo "======================================================"
echo ""
