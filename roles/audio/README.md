# Role `audio`

Configures PipeWire and WirePlumber for an Alpine Linux KDE desktop.

## Scope

The role:

- installs PipeWire and WirePlumber;
- provides PulseAudio, ALSA and JACK compatibility;
- installs the Qt audio mixer for Plasma;
- adds the desktop user to the `audio` group;
- enables PipeWire, WirePlumber and PipeWire Pulse as OpenRC user services;
- registers the services in both `gui` and `default` user runlevels so the
  configuration works with Wayland and X11 sessions;
- reports the user runlevel and audio graph after installation.

The role does not use the legacy `pipewire-launcher`. After installation, log
out and back in so the user services start in the graphical session.

Bluetooth audio support is provided by `pipewire-spa-bluez`, enabled in the
Bluetooth role when audio is enabled.
