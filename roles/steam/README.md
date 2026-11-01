# Role `steam`

Instala a Steam no perfil do usuário por meio do canal Nix configurado pela role `nix`.

Pré-requisitos:

- role `nix` executada anteriormente;
- `nix_permitir_nao_livres: true`;
- usuário existente em `usuario_desktop`;
- canal `nixpkgs` atualizado.

A biblioteca Steam em um HD separado não é montada por esta role. O volume deve estar montado antes de iniciar a Steam; a automação do armazenamento será adicionada em uma etapa posterior.
