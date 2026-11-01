# Role `energia`

Integrates elogind and polkit with SDDM so the login screen can expose local
power actions without granting the `sddm` user general root access.

The rule is limited to suspend, hibernate, hybrid sleep, suspend-then-hibernate,
reboot and power-off actions. It does not change the system doas policy.

Hibernation requires a swap partition or file and a matching kernel `resume=`
parameter. The role reports swap and `loginctl` capabilities but does not alter
the bootloader automatically.
