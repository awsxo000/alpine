# Documentação por role

| Role | Pacotes | Serviços | Variáveis principais |
|------|---------|----------|----------------------|
| base | doas bash curl git shadow | — | `base_pacotes` |
| nix | nix nix-openrc | nix-daemon (default) | `nix_canal_versao`, `nix_habilitar_flakes` (false), `nix_permitir_nao_livres`, `nix_pacotes_usuario`, `usuario_desktop` |
| steam | Steam pelo Nixpkgs | — | `steam_habilitado`, `steam_pacote`, `steam_atualizar_menu_kde` |
| nix_opengl | (Nix) mesa, pkgsi686Linux.mesa | local (default) | `nix_opengl_habilitado`, `nix_opengl_driver_teste` |
| rede | networkmanager (+wifi, cli), plasma-nm, eudev, wpa_supplicant | networkmanager, udev | `rede_dhcp`, `rede_wifi_backend`, `rede_grupo_usuario`, `rede_desabilitar_servicos_legados` |
| bluetooth | bluez, bluedevil, rfkill, kmod | bluetooth | `bluetooth_habilitado`, `bluetooth_auto_enable`, `bluetooth_userspace_hid`, `bluetooth_instalar_pipewire_spa_bluez` |
| audio | pipewire, wireplumber, pipewire-pulse, pipewire-alsa, pipewire-jack, pavucontrol-qt | serviços OpenRC do usuário | `audio_pacotes`, `audio_runlevels_usuario` |
| energia | elogind, polkit-elogind | elogind, polkit | `energia_habilitada`, `energia_configurar_sddm`, `energia_usuario_login` |
| fontes | fontconfig dejavu liberation noto noto-emoji noto-cjk inter jetbrains-mono | — | `fontes_pacotes_extras` |

## Arquivos gerenciados no alvo
- `/etc/nix/nix.conf`, `/etc/profile.d/nix-desktop.sh`
- `/etc/NetworkManager/NetworkManager.conf`
- `/etc/apk/repositories` (só descomenta o `community`)
- `~/.config/nixpkgs/config.nix`, `~/.cache/nix-roots/mesa{64,32}` (não apagar)
- `/etc/local.d/opengl-drivers.start`, links `/run/opengl-driver{,-32}`

## Referência validada à mão
`docs/referencia/guia-instalacao-manual.md` (Alpine 3.24.3, Nix 2.31.5, KDE, usuário `saw`).
