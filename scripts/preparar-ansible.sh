#!/bin/sh
set -eu

# Preparação da máquina local antes de executar qualquer playbook Ansible.
# Idempotente: pode ser executado quantas vezes for preciso.
#
# O que faz:
#   1. detecta o usuário da máquina (quem vai usar o Nix/Steam);
#   2. instala make, Python 3, Ansible e doas via apk;
#   3. garante a regra `permit nopass <usuário>` em /etc/doas.d/99-alpine-desktop.conf
#      (valendo para qualquer usuário de destino, pois as roles usam become_user);
#   4. grava `usuario_desktop` em inventarios/producao/host_vars/localhost.yml;
#   5. instala a coleção community.general.
#
# Para forçar outro usuário:  USUARIO_DESKTOP=maria sh scripts/preparar-ansible.sh

PROJETO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$PROJETO_DIR"

if ! command -v apk >/dev/null 2>&1; then
    echo "Erro: este script precisa ser executado em um sistema Alpine Linux." >&2
    exit 1
fi

# ---------------------------------------------------------------- usuário alvo
detectar_usuario() {
    # 1) variável explícita
    if [ -n "${USUARIO_DESKTOP:-}" ]; then
        echo "$USUARIO_DESKTOP"; return
    fi
    # 2) usuário comum que executou o script
    if [ "$(id -u)" -ne 0 ]; then
        id -un; return
    fi
    # 3) executado como root: quem chamou doas/sudo
    for candidato in "${DOAS_USER:-}" "${SUDO_USER:-}"; do
        if [ -n "$candidato" ] && [ "$candidato" != "root" ]; then
            echo "$candidato"; return
        fi
    done
    # 4) dono da pasta do projeto
    dono=$(stat -c %U "$PROJETO_DIR" 2>/dev/null || true)
    if [ -n "$dono" ] && [ "$dono" != "root" ] && [ "$dono" != "UNKNOWN" ]; then
        echo "$dono"; return
    fi
    # 5) primeiro usuário comum (UID >= 1000)
    awk -F: '$3 >= 1000 && $3 < 60000 { print $1; exit }' /etc/passwd
}

USUARIO_ALVO=$(detectar_usuario)

if [ -z "$USUARIO_ALVO" ] || [ "$USUARIO_ALVO" = "root" ]; then
    echo "Erro: não consegui detectar o usuário do desktop." >&2
    echo "      Rode: USUARIO_DESKTOP=seu_usuario sh scripts/preparar-ansible.sh" >&2
    exit 1
fi
if ! id "$USUARIO_ALVO" >/dev/null 2>&1; then
    echo "Erro: o usuário '$USUARIO_ALVO' não existe neste sistema." >&2
    exit 1
fi
USUARIO_HOME=$(awk -F: -v u="$USUARIO_ALVO" '$1 == u { print $6 }' /etc/passwd)
echo "==> Usuário do desktop: $USUARIO_ALVO (home: ${USUARIO_HOME:-?})"

# ------------------------------------------------------------------ privilégio
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

# ------------------------------------------------------------------- regra doas
# A regra vai num drop-in /etc/doas.d/99-*.conf, que o doas lê DEPOIS do
# /etc/doas.conf e por isso não pode ser sobrescrita por regras como
# "permit persist :wheel". Sem "as <alvo>": o Ansible faz become para root E
# para o usuário do desktop (become_user nas roles nix, steam e nix_opengl).
echo "==> Configurando doas para o Ansible local (${USUARIO_ALVO})"
DOAS_CONF=/etc/doas.conf
DOAS_DROPIN=/etc/doas.d/99-alpine-desktop.conf
TMP_DOAS=$(mktemp)
trap 'rm -f "$TMP_DOAS"' EXIT

printf '# Gerado por alpine-desktop (scripts/preparar-ansible.sh)\npermit nopass %s\n' \
    "$USUARIO_ALVO" > "$TMP_DOAS"
doas -C "$TMP_DOAS" || { echo "Erro: regra do doas gerada é inválida." >&2; exit 1; }

$PRIVILEGIO mkdir -p /etc/doas.d
if ! $PRIVILEGIO cmp -s "$TMP_DOAS" "$DOAS_DROPIN" 2>/dev/null; then
    $PRIVILEGIO install -m 0400 -o root -g root "$TMP_DOAS" "$DOAS_DROPIN"
    echo "    regra gravada em $DOAS_DROPIN"
else
    echo "    regra já presente em $DOAS_DROPIN"
fi

# Migração: remove a regra deixada por versões anteriores deste script no doas.conf.
if $PRIVILEGIO grep -Eq "^permit[[:space:]]+nopass[[:space:]]+${USUARIO_ALVO}([[:space:]]+as[[:space:]]+root)?[[:space:]]*$" "$DOAS_CONF" 2>/dev/null; then
    $PRIVILEGIO sed -i -E "/^permit[[:space:]]+nopass[[:space:]]+${USUARIO_ALVO}([[:space:]]+as[[:space:]]+root)?[[:space:]]*$/d" "$DOAS_CONF"
    echo "    regra antiga removida de $DOAS_CONF"
fi

# Valida como o usuário do desktop (o Ansible nunca roda como root).
executar_como_usuario() {
    if [ "$(id -u)" -eq 0 ]; then
        su -s /bin/sh "$USUARIO_ALVO" -c "cd '$PROJETO_DIR' && $1"
    else
        sh -c "$1"
    fi
}
if ! executar_como_usuario "doas -n true"; then
    echo "Erro: 'doas -n true' (become root) falhou para '$USUARIO_ALVO'." >&2
    echo "      Veja: su -c 'ls -l /etc/doas.d; head -n 50 /etc/doas.conf /etc/doas.d/*'" >&2
    exit 1
fi
if ! executar_como_usuario "doas -n -u '$USUARIO_ALVO' true"; then
    echo "Erro: 'doas -n -u $USUARIO_ALVO true' (become_user) falhou." >&2
    echo "      Veja: su -c 'ls -l /etc/doas.d; head -n 50 /etc/doas.conf /etc/doas.d/*'" >&2
    exit 1
fi
echo "    doas sem senha validado"

# ------------------------------------------------------------ variável do Ansible
HOST_VARS="inventarios/producao/host_vars/localhost.yml"
mkdir -p "$(dirname "$HOST_VARS")"
if [ ! -f "$HOST_VARS" ]; then
    cat > "$HOST_VARS" <<VARS
---
# Gerado por scripts/preparar-ansible.sh. Pode editar; não será sobrescrito.
usuario_desktop: ${USUARIO_ALVO}
VARS
    [ "$(id -u)" -eq 0 ] && chown "$USUARIO_ALVO" "$HOST_VARS" "$(dirname "$HOST_VARS")"
    echo "==> Gravado $HOST_VARS (usuario_desktop: ${USUARIO_ALVO})"
elif ! grep -Eq "^usuario_desktop:[[:space:]]*${USUARIO_ALVO}[[:space:]]*$" "$HOST_VARS"; then
    echo "Aviso: $HOST_VARS já existe com outro usuario_desktop; mantido." >&2
    echo "       Detectado agora: ${USUARIO_ALVO}. Ajuste o arquivo se necessário." >&2
fi

# ------------------------------------------------- donos de arquivos do Ansible
# Execuções anteriores como root deixam ~/.ansible, .collections e .cache com dono
# root, e o Ansible do usuário falha com "Unable to create local directories".
UID_ALVO=$(id -u "$USUARIO_ALVO")
GID_ALVO=$(id -g "$USUARIO_ALVO")
for alvo in "${USUARIO_HOME:-/nonexistent}/.ansible" "$PROJETO_DIR/.collections" "$PROJETO_DIR/.cache" "$PROJETO_DIR/inventarios/producao/host_vars"; do
    if [ -e "$alvo" ] && [ -n "$(find "$alvo" ! -user "$USUARIO_ALVO" -print -quit 2>/dev/null)" ]; then
        echo "==> Corrigindo dono de $alvo para $USUARIO_ALVO"
        $PRIVILEGIO chown -R "$UID_ALVO:$GID_ALVO" "$alvo"
    fi
done

# ------------------------------------------------------------------ ferramentas
echo "==> Verificando ferramentas"
command -v python3 >/dev/null
command -v ansible-playbook >/dev/null
command -v ansible-galaxy >/dev/null

printf 'Python: '
python3 --version
printf 'Ansible: '
ansible-playbook --version | sed -n '1p'

echo "==> Instalando a coleção community.general"
executar_como_usuario "ansible-galaxy collection install -r requirements.yml -p .collections"

echo "==> Preparação do Ansible concluída"
