#!/bin/sh
set -eu

PROJETO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SAIDA=${1:-"$PROJETO_DIR/../alpine-desktop-release.zip"}
ESTAGIO=$(mktemp -d)
trap 'rm -rf "$ESTAGIO"' EXIT

mkdir -p "$ESTAGIO/alpine-desktop"
cp -a "$PROJETO_DIR/." "$ESTAGIO/alpine-desktop/"
rm -rf "$ESTAGIO/alpine-desktop/.git" \
       "$ESTAGIO/alpine-desktop/.collections" \
       "$ESTAGIO/alpine-desktop/.cache" \
       "$ESTAGIO/alpine-desktop/docs/evidencias"

rm -f "$SAIDA"
(
    cd "$ESTAGIO"
    zip -qr "$SAIDA" alpine-desktop \
        -x 'alpine-desktop/*.retry' 'alpine-desktop/.vault_pass'
)

if unzip -Z1 "$SAIDA" | grep -q 'alpine-desktop/docs/evidencias/'; then
    echo "Erro: evidências foram incluídas no pacote." >&2
    exit 1
fi

printf '%s\n' "Pacote criado: $SAIDA"
