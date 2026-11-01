# ADR-0001: Nix como fonte complementar de pacotes
- Status: aceito
- Contexto: o apk é baseado em musl; muitos binários exigem glibc.
- Decisão: usar o `nix` do repositório community do Alpine, com nix-daemon (multiusuário) via OpenRC,
  canal estável e sem flakes (recurso experimental).
- Consequências: `/nix/store` ocupa disco; apps gráficos com OpenGL/Vulkan do Nix precisam de
  solução para os drivers (ver ADR-0002); sessões gráficas devem carregar `/etc/profile.d`.
