# alpine-desktop

Ansible automation for an existing Alpine Linux desktop (`setup-alpine` + `setup-desktop`).

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
base → nix → steam → nix_opengl → rede
```

To reapply the configuration:

```sh
make aplicar
```

To prepare dependencies without applying the desktop:

```sh
make dependencias
```

## Optional roles

Audio and font roles are implemented but disabled by default. NetworkManager is
the current validation stage:

```yaml
rede_habilitada: true

audio_habilitado: false

fontes_habilitadas: false
```

After applying the network stage, log in again so the `plugdev` group takes
effect in the desktop session.

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

The bootstrap configures a dedicated `doas` rule for the detected desktop user,
allowing Ansible to run locally without an interactive password prompt. The
configuration is idempotent and validates the generated rule before use.

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
