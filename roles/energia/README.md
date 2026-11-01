# Role `energia`

Integrates elogind and polkit with SDDM so the login screen can expose local
power actions without granting the `sddm` user general root access.

By default, the rule permits suspend, reboot and power-off. Hibernation,
hybrid sleep and suspend-then-hibernate are disabled because they require a
properly sized persistent swap and a valid kernel resume configuration. It does
not change the system doas policy.

Set `energia_habilitar_hibernacao: true` only after configuring a suitable swap
partition or file and a matching kernel `resume=` parameter. The role reports
swap and `loginctl` capabilities but does not alter the bootloader automatically.
