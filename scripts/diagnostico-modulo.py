#!/usr/bin/env python3
"""Diagnóstico somente leitura dos módulos do alpine-desktop.

A saída padrão é JSON versionado para consumo do Alpine Desktop Center.
Nenhum check deste arquivo modifica o sistema.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import pwd
import shutil
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Callable

SCHEMA_VERSION = 1
CATALOG_PATH = Path(__file__).resolve().parents[1] / "modulos.json"


def module_catalog() -> tuple[dict[str, object], ...]:
    with CATALOG_PATH.open(encoding="utf-8") as stream:
        catalog = json.load(stream)
    if not isinstance(catalog, list) or not all(isinstance(item, dict) for item in catalog):
        raise ValueError("modulos.json deve conter uma lista de módulos")
    return tuple(catalog)


MODULE_CATALOG = module_catalog()
MODULES = tuple(str(item["key"]) for item in MODULE_CATALOG)


@dataclass(frozen=True)
class Check:
    key: str
    title: str
    description: str
    run: Callable[[], tuple[str, str]]
    required: bool = True


def command_exists(name: str) -> bool:
    return shutil.which(name) is not None


def package_installed(name: str) -> bool:
    if not command_exists("apk"):
        return False
    return subprocess.run(["apk", "info", "-e", name], stdout=subprocess.DEVNULL,
                          stderr=subprocess.DEVNULL, check=False).returncode == 0


def service_running(name: str) -> bool:
    if not command_exists("rc-service"):
        return False
    return subprocess.run(["rc-service", name, "status"], stdout=subprocess.DEVNULL,
                          stderr=subprocess.DEVNULL, check=False).returncode == 0


def path_exists(path: str | Path) -> bool:
    return Path(path).exists()


def groups_for_user() -> set[str]:
    try:
        user = os.environ.get("USER") or pwd.getpwuid(os.getuid()).pw_name
        result = subprocess.run(["id", "-nG", user], capture_output=True, text=True, check=False)
        return set(result.stdout.split())
    except (OSError, KeyError):
        return set()


def process_running(name: str) -> bool:
    if command_exists("pgrep"):
        found = subprocess.run(["pgrep", "-x", name], stdout=subprocess.DEVNULL,
                               stderr=subprocess.DEVNULL, check=False).returncode == 0
        if found:
            return True
    if not command_exists("ps"):
        return False
    result = subprocess.run(["ps", "-eo", "comm="], capture_output=True, text=True, check=False)
    return any(line.strip() == name for line in result.stdout.splitlines())


def command_output(command: list[str]) -> tuple[int, str, str]:
    completed = subprocess.run(command, capture_output=True, text=True, check=False)
    return completed.returncode, completed.stdout, completed.stderr


def audio_server_status() -> tuple[str, str]:
    """Use session-level PipeWire APIs as the source of truth for audio."""
    wpctl_ok = False
    wpctl_output = ""
    if command_exists("wpctl"):
        code, stdout, stderr = command_output(["wpctl", "status"])
        wpctl_output = stdout or stderr
        wpctl_ok = code == 0 and "PipeWire" in wpctl_output

    pactl_ok = False
    pactl_output = ""
    if command_exists("pactl"):
        code, stdout, stderr = command_output(["pactl", "info"])
        pactl_output = stdout or stderr
        pactl_ok = code == 0 and "PipeWire" in pactl_output

    if wpctl_ok and pactl_ok:
        sinks = "Sinks:" in wpctl_output
        sources = "Sources:" in wpctl_output
        detail = "Servidor PipeWire acessível via wpctl e pactl"
        if sinks or sources:
            detail += "; dispositivos de áudio enumerados"
        return "ok", detail + "."
    if wpctl_ok or pactl_ok:
        return "warning", "Servidor de áudio parcialmente acessível; uma das APIs da sessão não respondeu."
    return "error", "Nenhum servidor PipeWire acessível via wpctl ou pactl."


def network_devices_status() -> tuple[str, str]:
    if not command_exists("nmcli"):
        return "warning", "nmcli não encontrado; não foi possível consultar dispositivos."
    code, stdout, stderr = command_output(["nmcli", "-t", "-f", "DEVICE,TYPE,STATE", "device"])
    if code != 0:
        return "warning", f"NetworkManager não respondeu à consulta: {(stderr or 'erro desconhecido').strip()}"
    rows = [line for line in stdout.splitlines() if line.strip() and not line.startswith("--:")]
    if rows:
        return "ok", f"{len(rows)} dispositivo(s) reportado(s) pelo NetworkManager."
    return "warning", "NetworkManager respondeu, mas não reportou dispositivos físicos."


def bluetooth_controller_status() -> tuple[str, str]:
    if not command_exists("bluetoothctl"):
        return "warning", "bluetoothctl não encontrado; não foi possível consultar controladores."
    code, stdout, stderr = command_output(["bluetoothctl", "list"])
    controllers = [line for line in stdout.splitlines() if "Controller" in line]
    if code == 0 and controllers:
        return "ok", f"{len(controllers)} controlador(es) Bluetooth encontrado(s)."
    return "warning", "Nenhum controlador Bluetooth foi enumerado."


def swap_active_status() -> tuple[str, str]:
    if Path("/proc/swaps").is_file():
        entries = [line for line in Path("/proc/swaps").read_text(errors="replace").splitlines()[1:] if line.strip()]
        if any(line.split()[0] == "/swapfile" for line in entries if line.split()):
            return "ok", "Swapfile está ativa no kernel."
    if command_exists("swapon"):
        code, stdout, _ = command_output(["swapon", "--show"])
        if code == 0 and "/swapfile" in stdout:
            return "ok", "Swapfile está ativa."
    return "error", "Swapfile não está ativa."


def run_check(check: Check) -> dict[str, object]:
    try:
        status, details = check.run()
    except OSError as exc:
        status, details = "unknown", f"Não foi possível executar a verificação: {exc}"
    return {
        "id": check.key,
        "title": check.title,
        "description": check.description,
        "status": status,
        "required": check.required,
        "message": details,
    }


def result(ok: bool, message: str) -> tuple[str, str]:
    return ("ok" if ok else "error", message)


def warning(ok: bool, message: str) -> tuple[str, str]:
    return ("ok" if ok else "warning", message)


def checks_for(module: str) -> tuple[Check, ...]:
    groups = groups_for_user()
    home = Path.home()

    def pkg(name: str, title: str) -> Check:
        return Check(name, title, f"Pacote Alpine {name}.", lambda: result(package_installed(name), f"{name} instalado." if package_installed(name) else f"{name} não está instalado."))

    if module == "base":
        return (
            pkg("doas", "doas instalado"),
            pkg("bash", "Bash instalado"),
            pkg("curl", "cURL instalado"),
            pkg("git", "Git instalado"),
            pkg("shadow", "Shadow instalado"),
            Check("community", "Repositório community disponível", "A configuração de repositórios Alpine contém community.", lambda: result(Path("/etc/apk/repositories").is_file() and "community" in Path("/etc/apk/repositories").read_text(errors="replace"), "Repositório community encontrado." if Path("/etc/apk/repositories").is_file() and "community" in Path("/etc/apk/repositories").read_text(errors="replace") else "Repositório community não encontrado.")),
            Check("ansible", "Ansible disponível", "O executável ansible-playbook está disponível.", lambda: result(command_exists("ansible-playbook"), "ansible-playbook disponível." if command_exists("ansible-playbook") else "ansible-playbook não encontrado.")),
        )
    if module == "nix":
        return (
            Check("nix", "Nix disponível", "Executável Nix no PATH ou perfil do usuário.", lambda: result(command_exists("nix") or (home / ".nix-profile/bin/nix").is_file(), "Nix disponível." if command_exists("nix") or (home / ".nix-profile/bin/nix").is_file() else "Nix não encontrado.")),
            pkg("nix", "Pacote Nix instalado"),
            Check("nix_daemon", "nix-daemon ativo", "Serviço OpenRC do daemon Nix.", lambda: result(service_running("nix-daemon"), "nix-daemon está ativo." if service_running("nix-daemon") else "nix-daemon não está ativo.")),
            Check("nix_config", "Configuração do Nix", "Arquivo de configuração gerado pela role.", lambda: result(Path("/etc/nix/nix.conf").is_file(), "nix.conf encontrado." if Path("/etc/nix/nix.conf").is_file() else "nix.conf não encontrado.")),
            Check("nix_updater", "Atualizador de aplicativos", "Utilitário instalado no perfil local.", lambda: result((home / ".local/bin/atualizar-aplicativos-nix.sh").is_file(), "Atualizador encontrado." if (home / ".local/bin/atualizar-aplicativos-nix.sh").is_file() else "Atualizador não encontrado."), required=False),
        )
    if module == "steam":
        return (
            Check("steam_profile", "Steam no perfil Nix", "Pacote Steam instalado para o usuário.", lambda: result(command_exists("steam") or (home / ".nix-profile/bin/steam").is_file(), "Steam encontrado." if command_exists("steam") or (home / ".nix-profile/bin/steam").is_file() else "Steam não encontrado no PATH nem no perfil Nix.")),
            Check("nix", "Dependência Nix", "Nix é necessário para a instalação declarada do Steam.", lambda: result(command_exists("nix") or (home / ".nix-profile/bin/nix").is_file(), "Nix disponível." if command_exists("nix") or (home / ".nix-profile/bin/nix").is_file() else "Dependência Nix ausente.")),
            Check("opengl", "Dependência OpenGL", "Links de drivers OpenGL para aplicativos Nix.", lambda: warning(Path("/run/opengl-driver").exists(), "Driver OpenGL encontrado." if Path("/run/opengl-driver").exists() else "Driver OpenGL não encontrado; jogos podem não iniciar.")),
        )
    if module == "nix_opengl":
        return (
            Check("mesa64", "Mesa 64 bits", "GC root Mesa de 64 bits.", lambda: result((home / ".cache/nix-roots/mesa64").exists(), "Mesa 64 bits encontrada." if (home / ".cache/nix-roots/mesa64").exists() else "Mesa 64 bits não encontrada.")),
            Check("mesa32", "Mesa 32 bits", "GC root Mesa de 32 bits.", lambda: result((home / ".cache/nix-roots/mesa32").exists(), "Mesa 32 bits encontrada." if (home / ".cache/nix-roots/mesa32").exists() else "Mesa 32 bits não encontrada.")),
            Check("boot_script", "Script OpenGL no boot", "Script local.d gerenciado pela role.", lambda: result(Path("/etc/local.d/opengl-drivers.start").is_file(), "Script OpenGL encontrado." if Path("/etc/local.d/opengl-drivers.start").is_file() else "Script OpenGL não encontrado.")),
            Check("driver_links", "Links OpenGL ativos", "Links de runtime para drivers Mesa.", lambda: result(Path("/run/opengl-driver").exists() and Path("/run/opengl-driver-32").exists(), "Links OpenGL 64 e 32 bits encontrados." if Path("/run/opengl-driver").exists() and Path("/run/opengl-driver-32").exists() else "Um ou mais links OpenGL estão ausentes.")),
        )
    if module == "rede":
        return (
            pkg("networkmanager", "NetworkManager instalado"),
            Check("networkmanager_service", "NetworkManager ativo", "Serviço OpenRC da rede.", lambda: result(service_running("networkmanager"), "NetworkManager está ativo." if service_running("networkmanager") else "NetworkManager não está ativo.")),
            Check("udev", "eudev ativo", "Serviço de dispositivos do sistema.", lambda: result(service_running("udev"), "udev está ativo." if service_running("udev") else "udev não está ativo.")),
            Check("plugdev", "Usuário no grupo plugdev", "Permissão para integração de dispositivos de rede.", lambda: result("plugdev" in groups, "Usuário está no grupo plugdev." if "plugdev" in groups else "Usuário não está no grupo plugdev.")),
            Check("managed_devices", "Dispositivos gerenciados", "NetworkManager reporta dispositivos gerenciados.", network_devices_status, required=False),
        )
    if module == "bluetooth":
        return (
            pkg("bluez", "BlueZ instalado"),
            Check("bluetooth_service", "Serviço Bluetooth ativo", "Serviço OpenRC bluetooth.", lambda: result(service_running("bluetooth"), "Bluetooth está ativo." if service_running("bluetooth") else "Bluetooth não está ativo.")),
            Check("bluetooth_controller", "Controlador Bluetooth encontrado", "Controlador descoberto por bluetoothctl.", bluetooth_controller_status, required=False),
            Check("btusb", "Módulo btusb carregado", "Driver USB Bluetooth do kernel.", lambda: warning(Path("/sys/module/btusb").exists(), "btusb carregado." if Path("/sys/module/btusb").exists() else "btusb não está carregado."), required=False),
            Check("rfkill", "Rádio Bluetooth desbloqueado", "Estado de bloqueio por software.", lambda: warning(not (command_exists("rfkill") and subprocess.run(["rfkill", "list", "bluetooth"], stdout=subprocess.PIPE, text=True, check=False).stdout.lower().find("soft blocked: yes") >= 0), "Rádio desbloqueado ou estado indisponível."), required=False),
        )
    if module == "audio":
        return (
            pkg("pipewire", "PipeWire instalado"), pkg("wireplumber", "WirePlumber instalado"),
            Check("audio_server", "Servidor PipeWire acessível", "Consulta a sessão real com wpctl e pactl.", audio_server_status),
            Check("pipewire_process", "PipeWire em execução", "Processo PipeWire do usuário.", lambda: warning(process_running("pipewire"), "Processo PipeWire encontrado." if process_running("pipewire") else "Processo não localizado diretamente; a sessão será avaliada por wpctl/pactl."), required=False),
            Check("wireplumber_process", "WirePlumber em execução", "Gerenciador de sessão do áudio.", lambda: warning(process_running("wireplumber"), "Processo WirePlumber encontrado." if process_running("wireplumber") else "Processo não localizado diretamente; a sessão será avaliada por wpctl/pactl."), required=False),
            Check("audio_group", "Usuário no grupo audio", "Permissão do usuário para áudio.", lambda: result("audio" in groups, "Usuário está no grupo audio." if "audio" in groups else "Usuário não está no grupo audio.")),
            Check("pulse_compat", "Compatibilidade PulseAudio", "Servidor compatível consultável por pactl.", lambda: warning(command_exists("pactl") and "PipeWire" in (command_output(["pactl", "info"])[1]), "Compatibilidade PulseAudio sobre PipeWire respondeu." if command_exists("pactl") else "pactl não encontrado; pode exigir novo login."), required=False),
        )
    if module == "swap":
        return (
            pkg("util-linux", "Utilitários de swap"),
            Check("swapfile", "Swapfile presente", "Arquivo /swapfile configurado pela role.", lambda: result(Path("/swapfile").is_file(), "Swapfile encontrado." if Path("/swapfile").is_file() else "Swapfile não encontrado.")),
            Check("swap_active", "Swap ativa", "Swap atualmente disponível para o kernel.", swap_active_status),
            Check("fstab", "Swap registrada no fstab", "Entrada persistente em /etc/fstab.", lambda: result(Path("/etc/fstab").is_file() and "/swapfile" in Path("/etc/fstab").read_text(errors="replace"), "Swapfile registrada." if Path("/etc/fstab").is_file() and "/swapfile" in Path("/etc/fstab").read_text(errors="replace") else "Swapfile não registrada.")),
        )
    if module == "energia":
        return (
            pkg("elogind", "elogind instalado"), pkg("polkit-elogind", "polkit integrado instalado"),
            Check("elogind_service", "elogind ativo", "Gerenciador de sessões.", lambda: result(service_running("elogind"), "elogind está ativo." if service_running("elogind") else "elogind não está ativo.")),
            Check("polkit_service", "polkit ativo", "Autorização de ações de energia.", lambda: result(service_running("polkit"), "polkit está ativo." if service_running("polkit") else "polkit não está ativo.")),
            Check("sddm_rules", "Regras de energia do SDDM", "Regra polkit gerenciada pelo backend.", lambda: result(Path("/etc/polkit-1/rules.d/49-alpine-sddm-power.rules").is_file(), "Regra do SDDM encontrada." if Path("/etc/polkit-1/rules.d/49-alpine-sddm-power.rules").is_file() else "Regra do SDDM não encontrada.")),
        )
    if module == "fontes":
        return (
            pkg("fontconfig", "Fontconfig instalado"), pkg("font-noto", "Fontes Noto instaladas"), pkg("font-noto-emoji", "Fontes Emoji instaladas"), pkg("font-noto-cjk", "Fontes CJK instaladas"),
            Check("font_cache", "Cache de fontes disponível", "fc-list consegue consultar as fontes.", lambda: result(command_exists("fc-list") and subprocess.run(["fc-list"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False).returncode == 0, "Cache de fontes consultável." if command_exists("fc-list") else "fc-list não encontrado.")),
        )
    if module == "kde":
        return (
            Check("plasma", "Plasma detectado", "Sessão ou executável Plasma.", lambda: result(command_exists("plasmashell") or bool(os.environ.get("KDE_FULL_SESSION")), "Plasma detectado." if command_exists("plasmashell") or os.environ.get("KDE_FULL_SESSION") else "Plasma não detectado.")),
            Check("kded", "kded6 disponível", "Serviço central do KDE.", lambda: result(command_exists("kded6"), "kded6 disponível." if command_exists("kded6") else "kded6 não encontrado.")),
            Check("systemmonitor_config", "System Monitor configurado", "Arquivo de configuração gerenciado pela role.", lambda: result((home / ".config/systemmonitorrc").is_file(), "Configuração encontrada." if (home / ".config/systemmonitorrc").is_file() else "Configuração não encontrada."), required=False),
            Check("overview_page", "Página Overview disponível", "Página Overview do System Monitor.", lambda: result((home / ".local/share/plasma-systemmonitor/overview.page").is_file(), "Página Overview encontrada." if (home / ".local/share/plasma-systemmonitor/overview.page").is_file() else "Página Overview não encontrada."), required=False),
        )
    raise ValueError(f"Módulo desconhecido: {module}")


def diagnose(module: str) -> dict[str, object]:
    checks = [run_check(check) for check in checks_for(module)]
    required = [check for check in checks if check["required"]]
    passed = sum(check["status"] == "ok" for check in checks)
    failed = sum(check["status"] == "error" for check in checks)
    warnings = sum(check["status"] == "warning" for check in checks)
    unknown = sum(check["status"] == "unknown" for check in checks)
    required_failed = any(check["status"] == "error" for check in required)
    required_unknown = any(check["status"] == "unknown" for check in required)
    required_passed = sum(check["status"] == "ok" for check in required)
    if required_unknown and required_passed == 0:
        status = "unknown"
    elif not required_failed and not required_unknown:
        status = "complete"
    elif required_passed > 0:
        status = "partial"
    else:
        status = "incomplete"
    catalog_entry = next(item for item in MODULE_CATALOG if item["key"] == module)
    dependencies = catalog_entry.get("dependencies", [])
    return {
        "schema_version": SCHEMA_VERSION,
        "module": module,
        "checked_at": dt.datetime.now().astimezone().isoformat(timespec="seconds"),
        "status": status,
        "summary": {"passed": passed, "failed": failed, "warnings": warnings, "unknown": unknown, "total": len(checks), "required_total": len(required)},
        "dependencies": [{"module": dep, "status": "not_checked"} for dep in dependencies],
        "checks": checks,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("module", choices=MODULES)
    parser.add_argument("--json", action="store_true", help="mantido por compatibilidade; JSON é o padrão")
    args = parser.parse_args()
    print(json.dumps(diagnose(args.module), ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
