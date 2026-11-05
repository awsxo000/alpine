#!/bin/sh
set -eu

# Prepara a máquina local antes de executar um playbook Ansible.
# O estado gerado fica em .alpine-state, fora do backend versionado.
# Operações privilegiadas usam autorização doas explícita no terminal do sistema.
BACKEND_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
PROJETO_DIR=$(CDPATH= cd -- "$BACKEND_DIR/.." && pwd)
cd "$BACKEND_DIR"

if ! command -v apk >/dev/null 2>&1; then
    echo "Erro: este script precisa ser executado em um sistema Alpine Linux." >&2
    exit 1
fi

detectar_usuario() {
    if [ -n "${USUARIO_DESKTOP:-}" ]; then echo "$USUARIO_DESKTOP"; return; fi
    if [ "$(id -u)" -ne 0 ]; then id -un; return; fi
    for candidato in "${DOAS_USER:-}" "${SUDO_USER:-}"; do
        if [ -n "$candidato" ] && [ "$candidato" != "root" ]; then echo "$candidato"; return; fi
    done
    dono=$(stat -c %U "$PROJETO_DIR" 2>/dev/null || true)
    if [ -n "$dono" ] && [ "$dono" != "root" ] && [ "$dono" != "UNKNOWN" ]; then echo "$dono"; return; fi
    awk -F: '$3 >= 1000 && $3 < 60000 { print $1; exit }' /etc/passwd
}

USUARIO_ALVO=$(detectar_usuario)
if [ -z "$USUARIO_ALVO" ] || [ "$USUARIO_ALVO" = "root" ]; then
    echo "Error: could not detect the desktop user." >&2
    echo "      Rode: USUARIO_DESKTOP=seu_usuario sh scripts/preparar-ansible.sh" >&2
    exit 1
fi
if ! id "$USUARIO_ALVO" >/dev/null 2>&1; then
    echo "Error: user '$USUARIO_ALVO' does not exist on this system." >&2
    exit 1
fi
USUARIO_HOME=$(awk -F: -v u="$USUARIO_ALVO" '$1 == u { print $6 }' /etc/passwd)
echo "==> Desktop user: $USUARIO_ALVO (home: ${USUARIO_HOME:-?})"

if [ "$(id -u)" -eq 0 ]; then
    PRIVILEGIO=""
elif command -v doas >/dev/null 2>&1; then
    PRIVILEGIO="doas"
else
    echo "Erro: execute como root ou instale/configure doas antes de continuar." >&2
    exit 1
fi

echo "==> Instalando make, Python 3, Ansible e doas no Alpine"
$PRIVILEGIO apk add --no-cache make python3 ansible doas

STATE_DIR="$PROJETO_DIR/.alpine-state"
mkdir -p "$STATE_DIR/collections"
cat > "$STATE_DIR/vars.yml" <<VARS
---
# Gerado por scripts/preparar-ansible.sh.
usuario_desktop: ${USUARIO_ALVO}
VARS

UID_ALVO=$(id -u "$USUARIO_ALVO")
GID_ALVO=$(id -g "$USUARIO_ALVO")
if [ "$(id -u)" -eq 0 ]; then
    chown -R "$UID_ALVO:$GID_ALVO" "$STATE_DIR"
fi
echo "==> Gravado $STATE_DIR/vars.yml (usuario_desktop: ${USUARIO_ALVO})"

# Execuções anteriores como root podem deixar o estado operacional sem permissão.
for alvo in "${USUARIO_HOME:-/nonexistent}/.ansible" "$STATE_DIR"; do
    if [ -e "$alvo" ] && [ -n "$(find "$alvo" ! -user "$USUARIO_ALVO" -print -quit 2>/dev/null)" ]; then
        echo "==> Corrigindo dono de $alvo para $USUARIO_ALVO"
        $PRIVILEGIO chown -R "$UID_ALVO:$GID_ALVO" "$alvo"
    fi
done

command -v python3 >/dev/null
command -v ansible-playbook >/dev/null
command -v ansible-galaxy >/dev/null
printf 'Python: '; python3 --version
printf 'Ansible: '; ansible-playbook --version | sed -n '1p'

echo "==> Installing community.general collection in .alpine-state/collections"
if [ "$(id -u)" -eq 0 ]; then
    su -s /bin/sh "$USUARIO_ALVO" -c "cd '$BACKEND_DIR' && ansible-galaxy collection install -r requirements.yml -p ../.alpine-state/collections"
else
    ansible-galaxy collection install -r requirements.yml -p ../.alpine-state/collections
fi

echo "==> Ansible preparation completed"
