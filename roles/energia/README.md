# Role `energia`

Integrates elogind and polkit with SDDM so the login screen can expose local
power actions without granting the `sddm` user general root access.

The rule permits suspend, reboot and power-off. Hibernation, hybrid sleep and
suspend-then-hibernate are controlled by `energia_habilitar_hibernacao`. When it
is enabled, the `swap` role discovers the root filesystem UUID and the physical
offset of `/swapfile`, then configures GRUB without assuming a fixed disk name.
The rule does not change the system doas policy.

The production inventory enables hibernation after creating the 12 GiB swapfile.
The role reports swap and `loginctl` capabilities and updates GRUB only when
hibernation is enabled. If a machine has a problematic firmware or graphics
driver, set `energia_habilitar_hibernacao: false` for that host.
