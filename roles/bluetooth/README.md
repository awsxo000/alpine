# Role `bluetooth`

Configures Bluetooth on an Alpine Linux KDE desktop using BlueZ.

## Scope

The role:

- installs `bluez`, `bluedevil`, `util-linux-misc` (which provides `rfkill`)
  and kernel-module tooling;
- adds the desktop user to the `lp` group;
- loads `btusb` and `uhid` and persists both modules at boot;
- enables automatic Bluetooth power-on by default;
- enables and starts the OpenRC `bluetooth` service;
- unblocks a software rfkill block when configured;
- validates the adapter with `rfkill`, `bluetoothctl` and the service status;
- optionally installs `pipewire-spa-bluez` for a later audio stage.

## Variables

```yaml
bluetooth_habilitado: true
bluetooth_auto_enable: true
bluetooth_experimental: false
bluetooth_userspace_hid: true
bluetooth_desbloquear_rfkill: true
bluetooth_instalar_pipewire_spa_bluez: false
```

After the first run, log out and back in so the `lp` group is applied to the
session. Use KDE Bluetooth or `bluetoothctl` to pair devices.
