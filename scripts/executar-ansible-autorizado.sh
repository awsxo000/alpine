#!/bin/sh
set -eu

if [ "$#" -eq 0 ]; then
    echo "Usage: $0 ansible-playbook-argument [argument...]" >&2
    exit 2
fi

BACKEND_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
if [ "$(id -u)" -ne 0 ]; then
    DOAS=/usr/bin/doas
    if [ ! -x "$DOAS" ]; then
        echo "Error: /usr/bin/doas is required to authorize this system operation." >&2
        exit 1
    fi
    # This is the only privilege transition. doas prompts in the visible system
    # terminal; no NOPASS rule is written or needed for the operation.
    exec "$DOAS" -u root "$BACKEND_DIR/scripts/executar-ansible-autorizado.sh" "$@"
fi

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
HOME=/root
export PATH HOME
cd "$BACKEND_DIR"

if ! command -v ansible-playbook >/dev/null 2>&1; then
    echo "Error: ansible-playbook is not installed; run make dependencias first." >&2
    exit 1
fi

# Migrate only the two broad project-owned drop-ins used by older releases.
# If removal fails, set -e aborts before Ansible can run.
/bin/rm -f \
    /etc/doas.d/99-alpine-desktop-temporario.conf \
    /etc/doas.d/99-alpine-desktop.conf

# Do not inherit caller-controlled Ansible or Python settings into the root run.
unset PYTHONPATH PYTHONHOME
unset ANSIBLE_INVENTORY ANSIBLE_LIBRARY ANSIBLE_COLLECTIONS_PATH ANSIBLE_ROLES_PATH
unset ANSIBLE_LOCAL_TEMP ANSIBLE_REMOTE_TEMP ANSIBLE_BECOME_PASSWORD
unset ANSIBLE_BECOME_EXE ANSIBLE_BECOME_FLAGS ANSIBLE_BECOME_USER ANSIBLE_BECOME_METHOD
ANSIBLE_CONFIG="$BACKEND_DIR/ansible.cfg"
ANSIBLE_BECOME_METHOD=su
PYTHONDONTWRITEBYTECODE=1
export ANSIBLE_CONFIG ANSIBLE_BECOME_METHOD PYTHONDONTWRITEBYTECODE
exec ansible-playbook "$@"
