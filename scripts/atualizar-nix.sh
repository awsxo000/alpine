#!/bin/sh
set -eu

# Atualizações explícitas do ambiente Nix do usuário do desktop.
# Este script não usa doas e não executa as roles Ansible.
export PATH="$HOME/.nix-profile/bin:/nix/var/nix/profiles/default/bin:${PATH:-}"

uso() {
    echo "Usage: $0 canal|aplicativos|tudo" >&2
    exit 2
}

[ "$#" -eq 1 ] || uso

atualizar_canal() {
    command -v nix-channel >/dev/null 2>&1 || {
        echo "Error: nix-channel is not available in the user profile." >&2
        return 1
    }
    echo "==> Updating configured Nix channels"
    nix-channel --update
}

atualizar_aplicativos() {
    if command -v nix-env >/dev/null 2>&1; then
        echo "==> Updating all applications installed with nix-env"
        nix-env -u '*'
        return
    fi
    if command -v nix >/dev/null 2>&1; then
        echo "==> Updating all applications in the Nix profile"
        nix profile upgrade '.*'
        return
    fi
    echo "Error: neither nix-env nor nix profile is available." >&2
    return 1
}

case "$1" in
    canal)
        atualizar_canal
        ;;
    aplicativos)
        atualizar_aplicativos
        ;;
    tudo)
        atualizar_canal
        atualizar_aplicativos
        ;;
    *)
        uso
        ;;
esac

echo "==> Nix update completed"
