# ADR-0002: Drivers gráficos do Nix para apps FHS
- Status: aceito (reboot ainda não validado)
- Contexto: no Alpine, o Steam (ambiente FHS do Nix) não encontrou os drivers gráficos.
- Decisão: baixar `mesa` e `pkgsi686Linux.mesa` do canal, mantê-los com `--out-link`
  em `~/.cache/nix-roots` e recriar `/run/opengl-driver{,-32}` a cada boot via `/etc/local.d`.
- Consequência: específico do hardware (`nix_opengl_driver_teste`, testado com radeonsi/AMD).
  O Mesa só é atualizado ao apagar os links e reexecutar a role.
