#!/bin/sh
set -eu

# Instala somente o aplicativo Refresh Nix Apps.
# Não executa Ansible, make, apk ou qualquer role do projeto.

BIN_DIR="$HOME/.local/bin"
APP_DIR="$HOME/.local/share/applications"
SCRIPT_DEST="$BIN_DIR/atualizar-aplicativos-nix.sh"
DESKTOP_DEST="$APP_DIR/atualizar-aplicativos-nix.desktop"

export PATH="$HOME/.nix-profile/bin:/nix/var/nix/profiles/default/bin:${PATH:-}"
export XDG_DATA_DIRS="$HOME/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:$HOME/.nix-profile/share:/nix/var/nix/profiles/default/share:/usr/local/share:/usr/share"

mkdir -p "$BIN_DIR" "$APP_DIR"

cat > "$SCRIPT_DEST" <<'APP'
#!/bin/sh
set -u

export PATH="$HOME/.nix-profile/bin:/nix/var/nix/profiles/default/bin:${PATH:-}"
export XDG_DATA_DIRS="$HOME/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:$HOME/.nix-profile/share:/nix/var/nix/profiles/default/share:/usr/local/share:/usr/share"

mensagem="Nix application menu refreshed."

rm -f "$HOME"/.cache/ksycoca* 2>/dev/null || true

if command -v xdg-desktop-menu >/dev/null 2>&1; then
    xdg-desktop-menu forceupdate >/dev/null 2>&1 || true
fi

if command -v kbuildsycoca6 >/dev/null 2>&1; then
    kbuildsycoca6 --noincremental >/dev/null 2>&1 || true
elif command -v kbuildsycoca5 >/dev/null 2>&1; then
    kbuildsycoca5 --noincremental >/dev/null 2>&1 || true
fi

if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true
fi

if command -v kdialog >/dev/null 2>&1; then
    kdialog --title "Refresh Nix Apps" --passivepopup "$mensagem" 5 >/dev/null 2>&1 || true
elif command -v notify-send >/dev/null 2>&1; then
    notify-send "Refresh Nix Apps" "$mensagem" >/dev/null 2>&1 || true
else
    printf '%s\n' "$mensagem"
fi

(
    sleep 1
    if command -v systemctl >/dev/null 2>&1 && systemctl --user is-active --quiet plasma-plasmashell.service 2>/dev/null; then
        systemctl --user restart plasma-plasmashell.service >/dev/null 2>&1 || true
    elif command -v plasmashell >/dev/null 2>&1; then
        plasmashell --replace >/dev/null 2>&1 &
    fi
) &
APP
chmod 0755 "$SCRIPT_DEST"

cat > "$DESKTOP_DEST" <<APP
[Desktop Entry]
Type=Application
Name=Refresh Nix Apps
Name[pt_BR]=Refresh Nix Apps
Comment=Refresh KDE menu entries for Nix-installed applications
Comment[pt_BR]=Refresh KDE menu entries for Nix-installed applications
Exec=$SCRIPT_DEST
Icon=system-software-update
Terminal=false
Categories=System;Settings;
StartupNotify=false
APP
chmod 0644 "$DESKTOP_DEST"

if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$APP_DIR" >/dev/null 2>&1 || true
fi
if command -v kbuildsycoca6 >/dev/null 2>&1; then
    kbuildsycoca6 --noincremental >/dev/null 2>&1 || true
elif command -v kbuildsycoca5 >/dev/null 2>&1; then
    kbuildsycoca5 --noincremental >/dev/null 2>&1 || true
fi

printf '%s\n' "Installed: Refresh Nix Apps"
printf '%s\n' "Launch it from the KDE application menu."
"$SCRIPT_DEST"
