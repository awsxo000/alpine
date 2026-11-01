#!/bin/sh
set -u

# Atualiza a integração gráfica dos aplicativos instalados pelo Nix.
# Este script é executado manualmente pelo launcher do menu; não faz parte
# da execução automática do playbook.

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

exit 0
