# Documentação por role

| Role | Pacotes | Serviços | Variáveis principais |
|------|---------|----------|----------------------|
| base | doas bash curl git shadow | — | `base_pacotes` |
| nix | nix nix-openrc | nix-daemon (default) | `nix_canal_versao`, `nix_habilitar_flakes` (false), `nix_permitir_nao_livres`, `nix_pacotes_usuario`, `usuario_desktop` |
| steam | Steam pelo Nixpkgs | — | `steam_habilitado`, `steam_pacote`, `steam_atualizar_menu_kde` |
| nix_opengl | (Nix) mesa, pkgsi686Linux.mesa | local (default) | `nix_opengl_habilitado`, `nix_opengl_driver_teste` |
| rede | networkmanager (+wifi, cli), plasma-nm, eudev, wpa_supplicant | networkmanager, udev | `rede_dhcp`, `rede_wifi_backend`, `rede_grupo_usuario`, `rede_desabilitar_servicos_legados` |
| bluetooth | bluez, bluez-openrc, bluedevil, util-linux-misc, kmod | bluetooth | `bluetooth_habilitado`, `bluetooth_auto_enable`, `bluetooth_userspace_hid`, `bluetooth_instalar_pipewire_spa_bluez` |
| audio | pipewire, pipewire-openrc, wireplumber, wireplumber-openrc, pipewire-pulse, pipewire-pulse-openrc, pipewire-alsa, pipewire-jack, pavucontrol-qt | serviços OpenRC do usuário | `audio_pacotes`, `audio_runlevels_usuario` |
| energia | elogind, elogind-openrc, polkit-elogind, polkit-openrc | elogind, polkit | `energia_habilitada`, `energia_configurar_sddm`, `energia_habilitar_hibernacao`, `energia_usuario_login` |
| swap | util-linux, e2fsprogs, e2fsprogs-extra | — | `swap_habilitada`, `swapfile_caminho`, `swapfile_tamanho_gib`, `swapfile_prioridade`, `energia_habilitar_hibernacao` |
| fontes | fontconfig, font-dejavu, font-liberation, font-noto, font-noto-cjk, font-noto-emoji, font-noto-extra, font-inter, font-jetbrains-mono | — | `fontes_habilitadas`, `fontes_pacotes_extras` |
| kde | — | — | `kde_habilitado`, `kde_system_monitor_ocultar_aplicacoes`, `kde_system_monitor_config`, `kde_system_monitor_overview` |

## Arquivos gerenciados no alvo
- `/etc/nix/nix.conf`, `/etc/profile.d/nix-desktop.sh`
- `/etc/NetworkManager/NetworkManager.conf`
- `/etc/apk/repositories` (só descomenta o `community`)
- `~/.config/nixpkgs/config.nix`, `~/.cache/nix-roots/mesa{64,32}` (não apagar)
- `/etc/local.d/opengl-drivers.start`, links `/run/opengl-driver{,-32}`
- `~/.config/systemmonitorrc` (oculta a página `Applications` incompatível com OpenRC)
- `~/.local/share/plasma-systemmonitor/overview.page` (remove o painel `Applications` do Overview)

## Referência validada à mão
`docs/referencia/guia-instalacao-manual.md` (Alpine 3.24.3, Nix 2.31.5, KDE, usuário `saw`).
