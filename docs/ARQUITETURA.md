# Arquitetura

## Premissa
O usuário instala o Alpine **manualmente** (`setup-alpine`) e o ambiente gráfico
(`setup-desktop`). O Ansible é executado na própria máquina, via `localhost`, e
**não** refaz o sistema: ele adiciona uma camada por cima.

## Objetivo central
Integrar o **Nix** ao Alpine para fornecer pacotes (inclusive os que dependem de glibc)
que o apk não tem. Os pacotes do Nix trazem a própria glibc em `/nix/store`, então rodam
sobre o musl do Alpine.

## Roles (ordem de execução)
1. **base** – garante o repositório `community` e os pacotes básicos
2. **nix** – nix + nix-daemon (OpenRC), canal estável, config.nix, integração XDG, pacotes do usuário
3. **steam** – Steam pelo Nixpkgs, com pacotes não livres habilitados
4. **nix_opengl** (opcional) – Mesa do Nix + links `/run/opengl-driver*` para apps FHS como o Steam
5. **rede** – NetworkManager
6. **audio** – PipeWire + WirePlumber
7. **fontes** – conjunto de fontes

## Etapas de ativação

A primeira execução habilita `base`, `nix`, `steam`, `nix_opengl` e a etapa
atual de `rede` com NetworkManager. As roles `audio` e `fontes` permanecem
desabilitadas até a validação da rede.

## Convenções
- Uma role = uma responsabilidade; variáveis ajustáveis em `group_vars`, padrões em `defaults/`.
- Variáveis levam o prefixo da role (ex.: `rede_dhcp`, `nix_canal_versao`).
- Serviços via OpenRC.
- Toda mudança vai para `docs/HISTORICO.md` e para a tabela em `docs/roles/README.md`.
