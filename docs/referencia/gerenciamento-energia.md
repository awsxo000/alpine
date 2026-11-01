# Gerenciamento de energia no Alpine KDE

Referências oficiais consultadas para a role `energia`:

- [Elogind — Alpine Wiki](https://wiki.alpinelinux.org/wiki/Elogind)
- [Polkit — Alpine Wiki](https://wiki.alpinelinux.org/wiki/Polkit)
- [Power management — Alpine Wiki](https://wiki.alpinelinux.org/wiki/Power_management)
- [KDE — Alpine Wiki](https://wiki.alpinelinux.org/wiki/KDE)

O Alpine documenta que o elogind fornece a integração de sessão e as ações de
energia via `loginctl`. O polkit deve ser integrado ao elogind para autorizações
com contexto de sessão. A hibernação exige swap e um parâmetro de kernel
`resume=` apontando para o dispositivo ou arquivo de swap correto.

A role autoriza apenas ações de energia ao usuário `sddm` na tela de login. Não
é concedido acesso root geral ao SDDM e o bootloader não é alterado
automaticamente.
