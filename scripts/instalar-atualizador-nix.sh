#!/bin/sh
set -eu

# Instala somente o aplicativo Atualizar aplicativos Nix.
# Não executa Ansible, make, apk ou qualquer role do projeto.

BIN_DIR="$HOME/.local/bin"
APP_DIR="$HOME/.local/share/applications"
SCRIPT_DEST="$BIN_DIR/atualizar-aplicativos-nix.sh"
DESKTOP_DEST="$APP_DIR/atualizar-aplicativos-nix.desktop"

mkdir -p "$BIN_DIR" "$APP_DIR"

cat > "$SCRIPT_DEST" <<'APP'
#!/bin/sh
set -u

export PATH="$HOME/.nix-profile/bin:/nix/var/nix/profiles/default/bin:${PATH:-}"
export XDG_DATA_DIRS="$HOME/.nix-profile/share:/nix/var/nix/profiles/default/share:/usr/local/share:/usr/share"

mensagem="Aplicativos Nix atualizados. Se algum comando ainda não aparecer no terminal, faça logout/login."

if command -v kbuildsycoca6 >/dev/null 2>&1; then
    kbuildsycoca6 --noincremental >/dev/null 2>&1 || true
elif command -v kbuildsycoca5 >/dev/null 2>&1; then
    kbuildsycoca5 --noincremental >/dev/null 2>&1 || true
fi

if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true
fi

if command -v kdialog >/dev/null 2>&1; then
    kdialog --title "Aplicativos Nix" --passivepopup "$mensagem" 5 >/dev/null 2>&1 || true
elif command -v notify-send >/dev/null 2>&1; then
    notify-send "Aplicativos Nix" "$mensagem" >/dev/null 2>&1 || true
else
    printf '%s\n' "$mensagem"
fi
APP
chmod 0755 "$SCRIPT_DEST"

cat > "$DESKTOP_DEST" <<APP
[Desktop Entry]
Type=Application
Name=Atualizar aplicativos Nix
Name[pt_BR]=Atualizar aplicativos Nix
Comment=Atualiza o menu do KDE para aplicativos instalados pelo Nix
Comment[pt_BR]=Atualiza o menu do KDE para aplicativos instalados pelo Nix
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

printf '%s\n' "Aplicativo instalado: Atualizar aplicativos Nix"
printf '%s\n' "Abra-o pelo menu do KDE com dois cliques."
