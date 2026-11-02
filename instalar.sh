#!/bin/sh
set -eu

# Instalador de primeira execução do alpine-desktop.
# Pode ser executado mesmo quando make ainda não está instalado, como usuário
# comum (recomendado) ou como root. O Ansible sempre roda como o usuário do
# desktop, nunca como root.
PROJETO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$PROJETO_DIR"

sh scripts/preparar-ansible.sh

echo "==> Chamando make instalar para aplicar o desktop"
if [ "$(id -u)" -eq 0 ]; then
    USUARIO=$(sed -n 's/^usuario_desktop:[[:space:]]*//p' .alpine-state/vars.yml | head -n1)
    [ -n "$USUARIO" ] || { echo "Erro: usuario_desktop não encontrado em .alpine-state/vars.yml" >&2; exit 1; }
    echo "==> Executando como '$USUARIO' (o Ansible não roda como root)"
    su -s /bin/sh "$USUARIO" -c "cd '$PROJETO_DIR' && make instalar"
else
    make instalar
fi

echo "==> Instalação concluída"
echo "==> Encerre e inicie a sessão gráfica novamente para atualizar o menu e o PATH."
