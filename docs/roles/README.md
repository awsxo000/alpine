# Documentação por role

| Role | Pacotes | Serviços | Variáveis principais |
|------|---------|----------|----------------------|
| base | doas bash curl git shadow | — | `base_pacotes` |
| nix | nix nix-openrc | nix-daemon (default) | `nix_canal_versao`, `nix_habilitar_flakes` (false), `nix_permitir_nao_livres`, `nix_pacotes_usuario`, `usuario_desktop` |
| steam | Steam pelo Nixpkgs | — | `steam_habilitado`, `steam_pacote`, `steam_atualizar_menu_kde` |
| nix_opengl | (Nix) mesa, pkgsi686Linux.mesa | local (default) | `nix_opengl_habilitado`, `nix_opengl_driver_teste` |
| rede | networkmanager (+wifi, cli) wpa_supplicant | networkmanager | `rede_dhcp`, `rede_desabilitar_servicos_legados` |
| audio | pipewire wireplumber pipewire-pulse pipewire-alsa alsa-utils pavucontrol | (do usuário, por sessão) | `audio_pacotes` |
| fontes | fontconfig dejavu liberation noto noto-emoji noto-cjk inter jetbrains-mono | — | `fontes_pacotes_extras` |

## Arquivos gerenciados no alvo
- `/etc/nix/nix.conf`, `/etc/profile.d/nix-desktop.sh`
- `/etc/NetworkManager/NetworkManager.conf`
- `/etc/apk/repositories` (só descomenta o `community`)
- `~/.config/nixpkgs/config.nix`, `~/.cache/nix-roots/mesa{64,32}` (não apagar)
- `/etc/local.d/opengl-drivers.start`, links `/run/opengl-driver{,-32}`

## Referência validada à mão
`docs/referencia/guia-instalacao-manual.md` (Alpine 3.24.3, Nix 2.31.5, KDE, usuário `saw`).
