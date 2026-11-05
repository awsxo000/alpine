#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
MAKEFILE="$ROOT/Makefile"
CONFIG="$ROOT/ansible.cfg"
RUNNER="$ROOT/scripts/executar-ansible-autorizado.sh"
BOOTSTRAP="$ROOT/scripts/preparar-ansible.sh"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

[ -x "$RUNNER" ] || fail "authorized Ansible runner must be executable"
sh -n "$RUNNER" || fail "authorized Ansible runner has invalid shell syntax"

# Every system-changing Ansible target must pass through the same one-shot runner.
[ "$(grep -Fc '$(ANSIBLE_RUNNER) ansible-playbook' "$MAKEFILE")" -eq 4 ] || \
    fail "expected four privileged Make targets to use ANSIBLE_RUNNER"
grep -Fq 'ANSIBLE_RUNNER = scripts/executar-ansible-autorizado.sh' "$MAKEFILE" || \
    fail "Makefile does not point to the authorized runner"
if grep -Fq 'TEMP_DOAS' "$MAKEFILE" || grep -Fq 'executar-com-doas-temporario' "$MAKEFILE"; then
    fail "Makefile still references the temporary NOPASS wrapper"
fi

# No code path may create a nopass rule; known legacy files are removed before exec.
if grep -Eiq 'permit[[:space:]]+nopass|doas[[:space:]]+install.*doas|cat.*>.*doas\.d' \
    "$RUNNER" "$BOOTSTRAP" "$MAKEFILE"; then
    fail "a privileged code path still creates a doas NOPASS rule"
fi
cleanup_line=$(grep -n -F '/bin/rm -f \' "$RUNNER" | cut -d: -f1)
exec_line=$(grep -n -F 'exec ansible-playbook "$@"' "$RUNNER" | cut -d: -f1)
[ -n "$cleanup_line" ] && [ -n "$exec_line" ] || fail "cleanup or playbook exec missing"
[ "$cleanup_line" -lt "$exec_line" ] || fail "legacy-rule cleanup must precede Ansible execution"
grep -Fq '/etc/doas.d/99-alpine-desktop-temporario.conf' "$RUNNER" || \
    fail "temporary legacy rule is not cleaned"
grep -Fq '/etc/doas.d/99-alpine-desktop.conf' "$RUNNER" || \
    fail "persistent legacy rule is not cleaned"
grep -Fq 'DOAS=/usr/bin/doas' "$RUNNER" || \
    fail "doas must be invoked from its system path, not through the user PATH"

grep -Eq 'become_method[[:space:]]*=[[:space:]]*su' "$CONFIG" || \
    fail "Ansible must switch users with su after the one-shot root authorization"

printf '%s\n' 'PASS: privileged Ansible operations use one-shot authorization; no NOPASS rule is created; legacy rules are removed before execution.'
