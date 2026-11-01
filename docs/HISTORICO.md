# Histórico (o que entra / o que sai)

Formato: `[data] tipo: descrição` — tipos: ADICIONADO, ALTERADO, REMOVIDO, CORRIGIDO.

## [2026-10-31] (6)
- ADICIONADO: role `steam`, que instala a Steam pelo canal Nixpkgs com pacotes não livres habilitados.
- ALTERADO: configuração de produção agora habilita `nix_permitir_nao_livres` e a preparação OpenGL por padrão.
- CORRIGIDO: role `nix` não referencia resultados de tarefas inexistentes quando não há pacotes extras declarados.

## [2026-10-31] (7)
- ALTERADO: inventário configurado para `localhost` com conexão local; removida a necessidade de IP e usuário SSH.
- ADICIONADO: alvo `make instalar` como atalho para aplicar todas as roles na máquina pessoal.

## [2026-10-31] (8)
- ADICIONADO: `scripts/preparar-ansible.sh` para instalar Python 3 e Ansible via `apk`.
- ALTERADO: `make dependencias` agora prepara o Ansible antes de instalar `community.general`.
- ALTERADO: `make instalar` executa preparação, coleções e aplicação completa do desktop.

## [2026-10-31] (9)
- CORRIGIDO: execução local documentada com regra `doas` `permit nopass`, pois o prompt de senha do `doas` exige TTY e não funciona com o `become` do Ansible.

## [2026-10-31] (10)
- CORRIGIDO: `/etc/profile.d/nix-desktop.sh` agora inclui `~/.nix-profile/bin` no `PATH`, tornando comandos como `steam` disponíveis em novas sessões.
- CORRIGIDO: role `nix_opengl` não repete mais a role `nix`, já executada explicitamente pelo playbook.

## [2026-10-31] (11)
- ADICIONADO: `instalar.sh`, instalador único que funciona mesmo antes de `make` existir.
- ALTERADO: `kbuildsycoca6` recebe explicitamente `PATH` e `XDG_DATA_DIRS` do perfil Nix após instalar pacotes.

## [2026-11-01] (12)
- ALTERADO: primeira etapa limitada a `base`, `nix`, `steam` e `nix_opengl`.
- ALTERADO: `rede`, `audio` e `fontes` ficam desabilitadas por padrão e serão habilitadas individualmente nas próximas etapas.

## [2026-11-01] (13)
- ALTERADO: `scripts/preparar-ansible.sh` configura automaticamente `permit nopass <usuário> as root` no `doas`.
- DOCUMENTADO: `make dependencias` é apenas a interface do Makefile para executar o script de preparação; não são duas implementações diferentes.

## [2026-11-01] (14)
- ALTERADO: `instalar.sh` agora prepara as dependências uma vez e chama `make instalar`.
- ALTERADO: `make instalar` aplica o desktop sem repetir `make dependencias`; este último ficou opcional.

## [2026-11-01] (15)
- CORRIGIDO: regra do `doas` passou a ser `permit nopass <usuário>` (sem `as root`); antes o `become_user` das roles nix/steam/nix_opengl falhava com `doas: Authentication required`.
- ADICIONADO: `scripts/preparar-ansible.sh` detecta o usuário da máquina, valida o `doas.conf` com `doas -C` e grava `usuario_desktop` em `host_vars/localhost.yml`; `USUARIO_DESKTOP` força outro usuário.
- ALTERADO: `usuario_desktop` removido do `group_vars`; `site.yml` exige que esteja definido.
- CORRIGIDO: rodar `instalar.sh` como root fazia o Ansible falhar com `doas: Authentication required` (become root→root); agora o script valida e executa `ansible-galaxy` e `make instalar` como o usuário do desktop via `su`.
- CORRIGIDO: a regra `nopass` agora vai em `/etc/doas.d/99-alpine-desktop.conf`; em `/etc/doas.conf` ela era sobrescrita pelos drop-ins de `/etc/doas.d/` e o `doas` continuava pedindo senha.
- CORRIGIDO: `preparar-ansible.sh` devolve ao usuário o dono de `~/.ansible`, `.collections`, `.cache` e `host_vars` quando execuções anteriores como root os deixaram com dono root.
- CORRIGIDO: aviso de deprecação `INJECT_FACTS_AS_VARS` (`ansible_facts['getent_group']`) e `HOME` nas tasks de canal do Nix.

## [2026-11-01] (16)
- ADICIONADO: aplicativo **Atualizar aplicativos Nix**, disponível no menu do KDE para execução manual com dois cliques.
- ALTERADO: o atualizador não é executado pelo playbook; ele apenas é instalado pela role `nix` e atualiza o cache quando o usuário o abrir.

## [2026-11-01] (17)
- ADICIONADO: `scripts/instalar-atualizador-nix.sh`, instalador independente que instala somente o aplicativo, sem Ansible, `make`, `apk`, `doas` ou execução das roles.

## [2026-11-01] (18)
- CORRIGIDO: atualizador agora remove o cache `ksycoca`, executa `xdg-desktop-menu forceupdate` e recarrega o `plasmashell` em segundo plano para atualizar o Kickoff sem reiniciar a máquina.

## [2026-11-01] (19)
- ALTERADO: aplicativo renomeado para **Refresh Nix Apps**, com nome e descrição em inglês no menu KDE.
- ALTERADO: README reduzido e reestruturado para uma apresentação mais objetiva e profissional.

## [2026-11-01] (20)
- CORRIGIDO: `XDG_DATA_DIRS` agora preserva os exports Flatpak do usuário e do sistema ao integrar aplicativos Nix com o KDE.

## [2026-10-31] (5)
- ALTERADO: projeto inteiro em português — roles `common`→`base`, `network`→`rede`, `fonts`→`fontes`;
  pastas `inventories/production`→`inventarios/producao`, `docs/decisions`→`docs/decisoes`,
  `docs/reference`→`docs/referencia`; `bootstrap.yml`→`preparacao.yml`;
  alvos do Makefile (`dependencias`, `preparar`, `sintaxe`, `lint`, `simular`, `aplicar`)
- ALTERADO: variáveis renomeadas (ex.: `desktop_user`→`usuario_desktop`, `nix_enable_flakes`→`nix_habilitar_flakes`,
  `nix_channel_release`→`nix_canal_versao`); lista completa nos `defaults/` de cada role e em `group_vars`
- ALTERADO: `ARCHITECTURE.md`→`ARQUITETURA.md`, `CHANGELOG.md`→`HISTORICO.md`

## [2026-10-31] (4) — baseado em `docs/referencia/guia-instalacao-manual.md`
- ADICIONADO: role `nix_opengl` (Mesa 64/32 bits do Nix, raízes de GC, `/etc/local.d/opengl-drivers.start`, serviço `local`) — opcional
- ADICIONADO: `~/.config/nixpkgs/config.nix` (allowUnfree) no lugar da variável `NIXPKGS_ALLOW_UNFREE`
- ADICIONADO: pacotes do usuário via `nix-env -iA` e atualização do menu do KDE (`kbuildsycoca6`)
- ALTERADO: o grupo do Nix tem `nix` como 1º candidato (confirmado no Alpine 3.24.3)
- ALTERADO: `nix.conf` mínimo; removidos `build-users-group`, `substituters` e `trusted-users` (padrões do pacote)
- PENDENTE: validar o reboot (links `/run/opengl-driver*`) e a biblioteca do Steam no HD

## [2026-10-31] (3)
- ALTERADO: Nix usa o canal estável `nixos-26.05` (antes: unstable), parametrizado por versão
- ALTERADO: flakes desligados por padrão — foco em estabilidade
- CORRIGIDO: a troca de canal agora é detectada pela URL (antes só pelo nome)
- NOTA: o 26.05 recebe correções até 31/12/2026; migrar para o 26.11 quando for lançado

## [2026-10-31] (2)
- ALTERADO: escopo — Alpine instalado manualmente; o Ansible vira camada extra
- REMOVIDO: roles users, graphics, session, desktop (o `setup-desktop` do Alpine já cobre)
- ADICIONADO: role `nix`; roles de rede, áudio e fontes ajustadas

## [2026-10-31] (1)
- ADICIONADO: estrutura inicial do projeto
