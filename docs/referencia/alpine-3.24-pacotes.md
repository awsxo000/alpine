# Pacotes validados no Alpine Linux 3.24

O alvo principal do projeto é Alpine Linux 3.24.3 stable. Os nomes abaixo foram
conferidos no índice oficial de pacotes `v3.24`:

- [bluez](https://pkgs.alpinelinux.org/package/v3.24/main/x86_64/bluez)
- [bluedevil](https://pkgs.alpinelinux.org/package/v3.24/community/x86_64/bluedevil)
- [util-linux-misc](https://pkgs.alpinelinux.org/package/v3.24/main/x86_64/util-linux-misc)
- [pipewire](https://pkgs.alpinelinux.org/package/v3.24/community/x86_64/pipewire)
- [wireplumber](https://pkgs.alpinelinux.org/package/v3.24/community/x86_64/wireplumber)
- [pipewire-spa-bluez](https://pkgs.alpinelinux.org/package/v3.24/community/x86_64/pipewire-spa-bluez)
- [polkit-elogind](https://pkgs.alpinelinux.org/package/v3.24/community/x86_64/polkit-elogind)
- [polkit-openrc](https://pkgs.alpinelinux.org/package/v3.24/community/x86_64/polkit-openrc)
- [elogind](https://pkgs.alpinelinux.org/package/v3.24/community/x86_64/elogind)
- [font-noto-cjk](https://pkgs.alpinelinux.org/package/v3.24/community/x86_64/font-noto-cjk)
- [font-noto-emoji](https://pkgs.alpinelinux.org/package/v3.24/community/x86_64/font-noto-emoji)
- [font-noto-extra](https://pkgs.alpinelinux.org/package/v3.24/community/x86_64/font-noto-extra)
- [font-inter](https://pkgs.alpinelinux.org/package/v3.24/community/x86_64/font-inter)
- [font-jetbrains-mono](https://pkgs.alpinelinux.org/package/v3.24/community/x86_64/font-jetbrains-mono)

Os serviços OpenRC são distribuídos como subpacotes separados em vários casos:
`bluez-openrc`, `pipewire-openrc`, `pipewire-pulse-openrc`,
`wireplumber-openrc`, `elogind-openrc` e `polkit-openrc`.

Para caracteres que aparecem como quadrados (tofu), a role `fontes` instala
`font-noto-cjk` e `font-noto-emoji`, atualiza o cache do Fontconfig e deixa o
KDE aplicar o fallback automaticamente. Aplicativos que já estavam abertos
devem ser fechados e reabertos para recarregar as fontes.
