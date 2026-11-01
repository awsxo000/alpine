# alpine-desktop

Camada Ansible sobre um Alpine já instalado (`setup-alpine` + `setup-desktop`):
Nix, Steam, rede, áudio e fontes.

## Uso rápido
```sh
make dependencias   # prepara Python/Ansible e instala as coleções
make simular        # dry-run
make aplicar        # aplica
make instalar       # aplica o desktop, após a preparação
ansible-playbook playbooks/site.yml --tags audio,fontes   # só algumas roles
```

Em uma máquina nova, o comando mais simples é executar diretamente o
instalador da raiz do projeto, mesmo que `make` ainda não esteja instalado:

```sh
sh instalar.sh
```

Ele prepara Python, Ansible e as coleções, aplica a primeira etapa (`base`,
`nix`, `steam` e `nix_opengl`) e avisa ao
final que é necessário iniciar uma nova sessão gráfica para que o menu do KDE
e o `PATH` dos aplicativos Nix sejam recarregados.

As integrações de rede, áudio e fontes estão implementadas, mas começam
desligadas. Só serão ativadas em etapas posteriores, alterando explicitamente
`rede_habilitada`, `audio_habilitado` ou `fontes_habilitadas` para `true`.

O projeto foi pensado para uso pessoal em uma única máquina. O inventário aponta
para `localhost` com conexão local; não é necessário informar IP, usuário SSH
ou configurar uma máquina remota. A execução completa é feita com:

```sh
make instalar
```

O alvo `make dependencias` chama o script Bash
`scripts/preparar-ansible.sh`, que instala `python3` e `ansible` pelo `apk` e
depois instala a coleção `community.general`. Como uma instalação mínima pode
ainda não ter o programa `make`, o primeiro bootstrap pode chamar o script
diretamente uma única vez:

```sh
sh scripts/preparar-ansible.sh
```

Depois disso, `make instalar` funciona normalmente. O alvo `make dependencias`
continua disponível para preparar apenas o ambiente, mas não é necessário no
fluxo normal porque `instalar.sh` já o executa antes de chamar `make instalar`.

Depois que essa etapa já foi feita, `make aplicar` reaplica somente as roles do
desktop, sem repetir a instalação das ferramentas do Ansible. O Ansible não
reinicia automaticamente a sessão gráfica atual: isso poderia interromper
aplicativos abertos. Por isso, após a primeira instalação, faça logout/login
ou reinicie a VM uma vez.

As tarefas administrativas usam `doas`, conforme configurado em `ansible.cfg`.
Como o `doas` da Alpine exige um TTY para autenticação por senha, o Ansible
local precisa de uma regra `nopass`. O `scripts/preparar-ansible.sh` (chamado por
`instalar.sh` e `make dependencias`) cuida de tudo sozinho:

- detecta o usuário da máquina (quem executou o script; se for root, usa
  `DOAS_USER`/`SUDO_USER`, o dono da pasta ou o primeiro usuário com UID >= 1000);
- grava `permit nopass <usuário>` em `/etc/doas.d/99-alpine-desktop.conf` (sem
  `as root`, pois as roles também usam `become_user`; o drop-in é lido depois do
  `doas.conf` e não é sobrescrito por `permit persist :wheel`), validando com `doas -C`;
- grava `usuario_desktop` em `inventarios/producao/host_vars/localhost.yml`.

Se `instalar.sh` for executado como root (`su`), o script faz apk e `doas.conf` como root e executa o restante (Ansible) como o usuário detectado.
Para forçar outro usuário: `USUARIO_DESKTOP=maria sh instalar.sh`.
Não é preciso editar `doas.conf` nem `group_vars` manualmente. Na primeira
execução o `doas` pedirá a senha uma única vez.

## Estrutura
```
inventarios/producao/   localhost + group_vars/host_vars
playbooks/              preparacao.yml, site.yml
roles/                  uma responsabilidade por role (base, nix, steam, nix_opengl, rede, audio, fontes)
docs/                   ARQUITETURA, HISTORICO, roles/, decisoes/, referencia/
```
Veja `docs/ARQUITETURA.md`.
