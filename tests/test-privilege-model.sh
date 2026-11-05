#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
MAKEFILE="$ROOT/Makefile"
CONFIG="$ROOT/ansible.cfg"
RUNNER="$ROOT/scripts/executar-ansible-autorizado.sh"
BOOTSTRAP="$ROOT/scripts/preparar-ansible.sh"
NIX_TASKS="$ROOT/roles/nix/tasks/main.yml"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

[ -x "$RUNNER" ] || fail "authorized Ansible runner must be executable"
sh -n "$RUNNER" || fail "authorized Ansible runner has invalid shell syntax"

# Every system-changing Ansible target must pass through the same one-shot runner.
[ "$(grep -Fc '$(ANSIBLE_RUNNER) playbooks/site.yml' "$MAKEFILE")" -eq 4 ] || \
    fail "expected four privileged Make targets to use ANSIBLE_RUNNER"
if grep -Fq '$(ANSIBLE_RUNNER) ansible-playbook' "$MAKEFILE"; then
    fail "runner must receive the playbook path, not the ansible-playbook executable name"
fi
for target in simular diagnostico aplicar aplicar-modulo; do
    dry_run=$(make -C "$ROOT" -n "$target" MODULO=audio) || fail "make -n failed for $target"
    printf '%s\n' "$dry_run" | grep -Fq 'scripts/executar-ansible-autorizado.sh playbooks/site.yml' || \
        fail "$target does not pass playbooks/site.yml as the runner's first argument"
    if printf '%s\n' "$dry_run" | grep -Fq 'scripts/executar-ansible-autorizado.sh ansible-playbook'; then
        fail "$target still passes the executable name as a playbook"
    fi
done
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

# A prior channel update may fail after nix-channel --add has persisted the URL.
# A later run must retry the download when the user's channel cache is absent.
grep -Fq 'path: "{{ usuario_desktop_home }}/.nix-defexpr/channels/{{ nix_canal_nome }}"' "$NIX_TASKS" || \
    fail "Nix role does not check whether the configured channel was downloaded"
grep -Fq 'register: nix_canal_cache' "$NIX_TASKS" || \
    fail "Nix channel cache stat result is not registered"
grep -Fq 'when: nix_canal_alterado is changed or not nix_canal_cache.stat.exists' "$NIX_TASKS" || \
    fail "Nix channel update will not retry after an incomplete first download"

printf '%s\n' 'PASS: privileged operations use one-shot authorization; legacy NOPASS rules are removed; Nix channel download retries when local cache is missing.'
