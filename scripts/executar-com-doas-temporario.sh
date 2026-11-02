#!/bin/sh
set -eu

# Executa uma operação Ansible com doas nopass somente durante esta operação.
# O drop-in é removido mesmo em sucesso, erro ou interrupção.
if [ "$#" -eq 0 ]; then
    echo "Uso: $0 comando [argumentos...]" >&2
    exit 2
fi
if [ "$(id -u)" -eq 0 ]; then
    echo "Erro: execute este wrapper como o usuário do desktop, não como root." >&2
    exit 1
fi
if ! command -v doas >/dev/null 2>&1; then
    echo "Erro: doas não está disponível." >&2
    exit 1
fi

DROPIN=/etc/doas.d/99-alpine-desktop-temporario.conf
TMP=$(mktemp)
cleanup() {
    doas -n rm -f "$DROPIN" >/dev/null 2>&1 || true
    rm -f "$TMP"
}
trap cleanup EXIT HUP INT TERM

printf '# Temporário: removido ao finalizar o comando Alpine Desktop Center\npermit nopass %s\n' "$(id -un)" > "$TMP"
doas mkdir -p /etc/doas.d
doas install -m 0400 -o root -g root "$TMP" "$DROPIN"
doas -C "$TMP"
doas -n true
doas -n -u "$(id -un)" true
"$@"
