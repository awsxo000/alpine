# Role `rede`

Configures NetworkManager as the primary network manager for an Alpine Linux
KDE desktop.

## Scope

The role:

- installs NetworkManager, Wi-Fi support, `nmcli` and `plasma-nm`;
- ensures the `eudev` service is enabled when available;
- configures `managed=true` through the `ifupdown` plugin;
- selects the configured Wi-Fi backend, defaulting to `wpa_supplicant`;
- adds the desktop user to `plugdev`;
- enables and starts the OpenRC `networkmanager` service;
- optionally stops and disables the legacy `networking` and
  `wpa_supplicant` services and removes them from the `boot` and `default`
  OpenRC runlevels;
- checks the NetworkManager service and reports the device state.

## Variables

```yaml
rede_habilitada: true
rede_desabilitar_servicos_legados: true
rede_dhcp: internal
rede_wifi_backend: wpa_supplicant
rede_grupo_usuario: plugdev
```

The legacy services are changed only when
`rede_desabilitar_servicos_legados` is `true`.

After the first run, log out and back in so the `plugdev` group is applied to
the graphical session. Use the KDE network applet or `nmcli` to create and
activate connections.
