#!/bin/sh
set -u

# Atualiza a integração gráfica dos aplicativos instalados pelo Nix.
# Este script é executado manualmente pelo launcher do menu; não faz parte
# da execução automática do playbook.

export PATH="$HOME/.nix-profile/bin:/nix/var/nix/profiles/default/bin:${PATH:-}"
export XDG_DATA_DIRS="$HOME/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:$HOME/.nix-profile/share:/nix/var/nix/profiles/default/share:/usr/local/share:/usr/share"

mensagem="Nix application menu refreshed."

# O Plasma pode manter uma cópia antiga da lista de aplicativos em memória.
# Remover o cache força o KService a reconstruí-lo com o XDG_DATA_DIRS atual.
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

# O Kickoff/Plasma pode não reconstruir a lista enquanto o plasmashell atual
# continua aberto. Recarregamos o shell em segundo plano, sem reboot e sem
# interromper o script antes da notificação aparecer.
(
    sleep 1
    if command -v systemctl >/dev/null 2>&1 && systemctl --user is-active --quiet plasma-plasmashell.service 2>/dev/null; then
        systemctl --user restart plasma-plasmashell.service >/dev/null 2>&1 || true
    elif command -v plasmashell >/dev/null 2>&1; then
        plasmashell --replace >/dev/null 2>&1 &
    fi
) &

exit 0
