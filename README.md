# alpine-desktop

Ansible automation for an existing Alpine Linux desktop (`setup-alpine` + `setup-desktop`).

The primary target is Alpine Linux **3.24.3 stable**. Package names and service
subpackages are validated against the Alpine `v3.24` repositories, not Edge.

The project adds Nix, Steam, Mesa/OpenGL integration and optional desktop services.
Execution is local through `localhost`; no SSH configuration is required.
Existing Flatpak exports are preserved in the desktop application environment.

## Quick start

On a new system:

```sh
sh instalar.sh
```

This bootstraps `make`, Python, Ansible, the required collection and the first
installation stage:

```text
base → nix → steam → nix_opengl → rede → bluetooth → audio → swap → energia → fontes → kde
```

To reapply the configuration:

```sh
make aplicar
```

The normal execution uses compact output and hides successful and skipped task
details. To inspect service, network, Bluetooth, audio and swap diagnostics,
run the explicit verbose target:

```sh
make diagnostico
```

To prepare dependencies without applying the desktop:

```sh
make dependencias
```

## Feature toggles

All integrated roles are enabled in the production inventory. NetworkManager,
Bluetooth, PipeWire, fonts and SDDM power actions are independently controlled:

```yaml
rede_habilitada: true

bluetooth_habilitado: true

audio_habilitado: true

energia_habilitada: true

fontes_habilitadas: true
```

After applying the network, Bluetooth and audio stages, log out and back in so
the `plugdev`, `lp` and `audio` groups and the PipeWire user services take
effect in the desktop session.

The swap role creates an additional swapfile and, when hibernation is enabled,
discovers the root UUID and swapfile offset before updating GRUB. No disk name
is hardcoded. Disable `energia_habilitar_hibernacao` per host if its firmware or
graphics drivers do not resume reliably.

## Refresh Nix Apps

The project installs **Refresh Nix Apps**, a KDE menu utility that refreshes
entries for applications installed through Nix. It is launched manually from
the application menu and does not run as part of the Ansible playbook.

To install only this utility, without Ansible, `make`, `apk` or root access:

```sh
sh scripts/instalar-atualizador-nix.sh
```

The utility can also be downloaded directly:

```sh
curl -fsSL \
  https://raw.githubusercontent.com/awsxo000/alpine/main/scripts/instalar-atualizador-nix.sh \
  -o /tmp/install-refresh-nix-apps.sh
sh /tmp/install-refresh-nix-apps.sh
```

## Privilege model

The bootstrap prepares `.alpine-state/vars.yml` and installs collections under
`.alpine-state/`, outside the versioned backend. Ansible executions create a
dedicated `doas nopass` rule only for the duration of the command and remove it
with a trap on success, failure or interruption; no permanent nopass rule is
installed by the bootstrap.

## Updating Nix

The backend exposes explicit user-level operations separate from Ansible:

```sh
make atualizar-canal-nix       # nix-channel --update
make atualizar-aplicativos-nix # nix-env -u '*' (or nix profile upgrade)
make atualizar-nix             # both operations in sequence
```

These commands do not use `doas`, change Alpine packages or execute roles.

The project interface exposes only the official Stable channel. To inspect or
migrate it manually through the backend:

```sh
make verificar-canal-stable-nix
make migrar-canal-stable-nix
```

The migration checks the official status page, changes the `nixpkgs` channel
to the latest `nixos-YY.MM` Stable release, updates it, and records the selected
version in `.alpine-state/vars.yml`. Unstable channels are intentionally not
offered by the project.

## Repository layout

```text
inventarios/   Local inventory and variables
playbooks/     Ansible playbooks
roles/         One responsibility per role
scripts/       Bootstrap and standalone utilities
docs/          Architecture, decisions and project history
```

Releases and standalone ZIP packages are published on GitHub:

<https://github.com/awsxo000/alpine/releases>

Test evidence is kept under `docs/evidencias/` in the repository and is not
included in Release ZIP packages.

To create a Release package locally:

```sh
sh scripts/empacotar-release.sh /tmp/alpine-desktop-release.zip
```
