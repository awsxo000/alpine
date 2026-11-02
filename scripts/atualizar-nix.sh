#!/bin/sh
set -eu

# Atualizações explícitas do ambiente Nix do usuário do desktop.
# Este script não usa doas e não executa as roles Ansible.
export PATH="$HOME/.nix-profile/bin:/nix/var/nix/profiles/default/bin:${PATH:-}"

uso() {
    echo "Uso: $0 canal|aplicativos|tudo" >&2
    exit 2
}

[ "$#" -eq 1 ] || uso

atualizar_canal() {
    command -v nix-channel >/dev/null 2>&1 || {
        echo "Erro: nix-channel não está disponível no perfil do usuário." >&2
        return 1
    }
    echo "==> Atualizando canais Nix configurados"
    nix-channel --update
}

atualizar_aplicativos() {
    if command -v nix-env >/dev/null 2>&1; then
        echo "==> Atualizando todos os aplicativos instalados com nix-env"
        nix-env -u '*'
        return
    fi
    if command -v nix >/dev/null 2>&1; then
        echo "==> Atualizando todos os aplicativos do perfil Nix"
        nix profile upgrade '.*'
        return
    fi
    echo "Erro: nem nix-env nem nix profile estão disponíveis." >&2
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

echo "==> Atualização Nix concluída"
