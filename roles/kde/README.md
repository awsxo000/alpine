# Role `kde`

Aplica ajustes de compatibilidade do KDE Plasma para o Alpine Linux com OpenRC.

O Plasma System Monitor mantém uma página `Applications` que depende da
integração de gerenciamento de aplicações baseada em systemd. Em sistemas sem
systemd, como o Alpine com OpenRC, essa página aparece mas mostra `Applications
view is unsupported on your system`.

A role oculta essa página no `systemmonitorrc` do usuário, preserva as páginas
`Overview`, `History` e `Processes` e define `Overview` como página inicial
válida. A alteração é idempotente e não remove o aplicativo System Monitor.

## Variáveis

- `kde_habilitado`: controla a execução da role no playbook.
- `kde_system_monitor_ocultar_aplicacoes`: habilita a ocultação da página; padrão `true`.
- `kde_system_monitor_config`: caminho do `systemmonitorrc` do usuário.

Para reexibir a página, defina `kde_system_monitor_ocultar_aplicacoes: false` e
remova manualmente `applications.page` de `hiddenPages` no arquivo de
configuração, se necessário.
