# Auditoria de estabilização

## Estado validado

A etapa atual executa `base`, `nix`, `steam`, `nix_opengl`, `rede`, `bluetooth`,
`audio` e `fontes`.

A role `rede` está validada no notebook de testes com NetworkManager, suporte
Wi-Fi, `plasma-nm`, `eudev`, grupo `plugdev` e remoção dos serviços OpenRC
legados dos runlevels. O serviço `wpa_supplicant` continua instalado como
backend do NetworkManager, mas não deve ser iniciado como serviço standalone.

## Limpeza realizada

- movidas as capturas de tela de teste para `docs/evidencias/rede/`; elas ficam
  na branch principal, mas são excluídas dos ZIPs de Release;
- alinhado o `XDG_DATA_DIRS` da role `steam` com a integração Nix/Flatpak;
- atualizado o README para refletir a rede na etapa atual;
- mantidos os scripts independentes e as roles sem funções duplicadas;
- mantidos os arquivos `.gitkeep`, pois preservam a estrutura padrão das roles.

## Verificações estáticas

- scripts shell validados com `sh -n`;
- `git diff --check` sem erros;
- variáveis do inventário referenciadas nas roles ou no playbook;
- áudio e fontes são controlados por suas flags no inventário;
- nenhum ZIP, cache, coleção Ansible ou `host_vars` gerado é versionado.

## Pontos intencionais

A atualização do menu KDE aparece em mais de um ponto porque cobre três
momentos diferentes: instalação de pacotes Nix, instalação da Steam e execução
manual do `Refresh Nix Apps`. A role `steam` não foi fundida à role `nix` para
manter responsabilidades separadas.

Antes de ativar uma nova role, executar `make simular` e revisar as mudanças.
Depois da aplicação, validar no notebook e criar um novo snapshot de referência.

A role de áudio usa os serviços de usuário do OpenRC e não combina esse método
com `pipewire-launcher`. O primeiro diagnóstico pode indicar que PipeWire ainda
não está disponível até o próximo logout/login.
