#!/usr/bin/env python3
"""Read-only diagnostics for alpine-desktop modules.

Standard output is versioned JSON for Alpine Desktop Center.
No check in this file modifies the system.
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
        raise ValueError("modulos.json must contain a list of modules")
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
        detail = "PipeWire server accessible through wpctl and pactl"
        if sinks or sources:
            detail += "; audio devices enumerated"
        return "ok", detail + "."
    if wpctl_ok or pactl_ok:
        return "warning", "Audio server is partially accessible; one session API did not respond."
    return "error", "No PipeWire server accessible through wpctl or pactl."


def network_devices_status() -> tuple[str, str]:
    if not command_exists("nmcli"):
        return "warning", "nmcli not found; devices could not be queried."
    code, stdout, stderr = command_output(["nmcli", "-t", "-f", "DEVICE,TYPE,STATE", "device"])
    if code != 0:
        return "warning", f"NetworkManager did not respond to the query: {(stderr or 'unknown error').strip()}"
    rows = [line for line in stdout.splitlines() if line.strip() and not line.startswith("--:")]
    if rows:
        return "ok", f"{len(rows)} device(s) reported by NetworkManager."
    return "warning", "NetworkManager responded, but reported no physical devices."


def bluetooth_controller_status() -> tuple[str, str]:
    if not command_exists("bluetoothctl"):
        return "warning", "bluetoothctl not found; controllers could not be queried."
    code, stdout, stderr = command_output(["bluetoothctl", "list"])
    controllers = [line for line in stdout.splitlines() if "Controller" in line]
    if code == 0 and controllers:
        return "ok", f"{len(controllers)} Bluetooth controller(s) found."
    return "warning", "No Bluetooth controller was enumerated."


def swap_active_status() -> tuple[str, str]:
    if Path("/proc/swaps").is_file():
        entries = [line for line in Path("/proc/swaps").read_text(errors="replace").splitlines()[1:] if line.strip()]
        if any(line.split()[0] == "/swapfile" for line in entries if line.split()):
            return "ok", "Swapfile is active in the kernel."
    if command_exists("swapon"):
        code, stdout, _ = command_output(["swapon", "--show"])
        if code == 0 and "/swapfile" in stdout:
            return "ok", "Swapfile is active."
    return "error", "Swapfile is not active."


def run_check(check: Check) -> dict[str, object]:
    try:
        status, details = check.run()
    except OSError as exc:
        status, details = "unknown", f"Could not run check: {exc}"
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
        return Check(name, title, f"Alpine package {name}.", lambda: result(package_installed(name), f"{name} installed." if package_installed(name) else f"{name} is not installed."))

    if module == "base":
        return (
            pkg("doas", "doas installed"),
            pkg("bash", "Bash installed"),
            pkg("curl", "cURL installed"),
            pkg("git", "Git installed"),
            pkg("shadow", "Shadow installed"),
            Check("community", "Community repository available", "Alpine repository configuration contains community.", lambda: result(Path("/etc/apk/repositories").is_file() and "community" in Path("/etc/apk/repositories").read_text(errors="replace"), "Community repository found." if Path("/etc/apk/repositories").is_file() and "community" in Path("/etc/apk/repositories").read_text(errors="replace") else "Community repository not found.")),
            Check("ansible", "Ansible available", "The ansible-playbook executable is available.", lambda: result(command_exists("ansible-playbook"), "ansible-playbook is available." if command_exists("ansible-playbook") else "ansible-playbook not found.")),
        )
    if module == "nix":
        return (
            Check("nix", "Nix available", "Nix executable in PATH or user profile.", lambda: result(command_exists("nix") or (home / ".nix-profile/bin/nix").is_file(), "Nix available." if command_exists("nix") or (home / ".nix-profile/bin/nix").is_file() else "Nix not found.")),
            pkg("nix", "Nix package installed"),
            Check("nix_daemon", "nix-daemon active", "Nix daemon OpenRC service.", lambda: result(service_running("nix-daemon"), "nix-daemon is active." if service_running("nix-daemon") else "nix-daemon is not active.")),
            Check("nix_config", "Nix configuration", "Configuration file generated by the role.", lambda: result(Path("/etc/nix/nix.conf").is_file(), "nix.conf found." if Path("/etc/nix/nix.conf").is_file() else "nix.conf not found.")),
            Check("nix_updater", "Application updater", "Utility installed in the local profile.", lambda: result((home / ".local/bin/atualizar-aplicativos-nix.sh").is_file(), "Updater found." if (home / ".local/bin/atualizar-aplicativos-nix.sh").is_file() else "Updater not found."), required=False),
        )
    if module == "steam":
        return (
            Check("steam_profile", "Steam in Nix profile", "Steam package installed for the user.", lambda: result(command_exists("steam") or (home / ".nix-profile/bin/steam").is_file(), "Steam found." if command_exists("steam") or (home / ".nix-profile/bin/steam").is_file() else "Steam not found in PATH or Nix profile.")),
            Check("nix", "Nix dependency", "Nix is required for the declared Steam installation.", lambda: result(command_exists("nix") or (home / ".nix-profile/bin/nix").is_file(), "Nix available." if command_exists("nix") or (home / ".nix-profile/bin/nix").is_file() else "Nix dependency is missing.")),
            Check("opengl", "OpenGL dependency", "OpenGL driver links for Nix applications.", lambda: warning(Path("/run/opengl-driver").exists(), "OpenGL driver found." if Path("/run/opengl-driver").exists() else "OpenGL driver not found; games may not start.")),
        )
    if module == "nix_opengl":
        return (
            Check("mesa64", "Mesa 64 bits", "GC root Mesa de 64 bits.", lambda: result((home / ".cache/nix-roots/mesa64").exists(), "64-bit Mesa found." if (home / ".cache/nix-roots/mesa64").exists() else "64-bit Mesa not found.")),
            Check("mesa32", "Mesa 32 bits", "GC root Mesa de 32 bits.", lambda: result((home / ".cache/nix-roots/mesa32").exists(), "32-bit Mesa found." if (home / ".cache/nix-roots/mesa32").exists() else "32-bit Mesa not found.")),
            Check("boot_script", "OpenGL boot script", "Role-managed local.d script.", lambda: result(Path("/etc/local.d/opengl-drivers.start").is_file(), "OpenGL script found." if Path("/etc/local.d/opengl-drivers.start").is_file() else "OpenGL script not found.")),
            Check("driver_links", "Active OpenGL links", "Runtime links for Mesa drivers.", lambda: result(Path("/run/opengl-driver").exists() and Path("/run/opengl-driver-32").exists(), "64-bit and 32-bit OpenGL links found." if Path("/run/opengl-driver").exists() and Path("/run/opengl-driver-32").exists() else "One or more OpenGL links are missing.")),
        )
    if module == "rede":
        return (
            pkg("networkmanager", "NetworkManager installed"),
            Check("networkmanager_service", "NetworkManager active", "Network OpenRC service.", lambda: result(service_running("networkmanager"), "NetworkManager is active." if service_running("networkmanager") else "NetworkManager is not active.")),
            Check("udev", "eudev active", "System device service.", lambda: result(service_running("udev"), "udev is active." if service_running("udev") else "udev is not active.")),
            Check("plugdev", "User in plugdev group", "Permission for network device integration.", lambda: result("plugdev" in groups, "User is in the plugdev group." if "plugdev" in groups else "User is not in the plugdev group.")),
            Check("managed_devices", "Managed devices", "NetworkManager reports managed devices.", network_devices_status, required=False),
        )
    if module == "bluetooth":
        return (
            pkg("bluez", "BlueZ installed"),
            Check("bluetooth_service", "Bluetooth service active", "Bluetooth OpenRC service.", lambda: result(service_running("bluetooth"), "Bluetooth is active." if service_running("bluetooth") else "Bluetooth is not active.")),
            Check("bluetooth_controller", "Bluetooth controller found", "Controller discovered by bluetoothctl.", bluetooth_controller_status, required=False),
            Check("btusb", "btusb module loaded", "Kernel Bluetooth USB driver.", lambda: warning(Path("/sys/module/btusb").exists(), "btusb loaded." if Path("/sys/module/btusb").exists() else "btusb is not loaded."), required=False),
            Check("rfkill", "Bluetooth radio unblocked", "Software block state.", lambda: warning(not (command_exists("rfkill") and subprocess.run(["rfkill", "list", "bluetooth"], stdout=subprocess.PIPE, text=True, check=False).stdout.lower().find("soft blocked: yes") >= 0), "Radio unblocked or state unavailable."), required=False),
        )
    if module == "audio":
        return (
            pkg("pipewire", "PipeWire installed"), pkg("wireplumber", "WirePlumber installed"),
            Check("audio_server", "Accessible PipeWire server", "Queries the real session with wpctl and pactl.", audio_server_status),
            Check("pipewire_process", "PipeWire running", "User PipeWire process.", lambda: warning(process_running("pipewire"), "PipeWire process found." if process_running("pipewire") else "Process not found directly; the session will be evaluated through wpctl/pactl."), required=False),
            Check("wireplumber_process", "WirePlumber running", "Audio session manager.", lambda: warning(process_running("wireplumber"), "WirePlumber process found." if process_running("wireplumber") else "Process not found directly; the session will be evaluated through wpctl/pactl."), required=False),
            Check("audio_group", "User in audio group", "User permission for audio.", lambda: result("audio" in groups, "User is in the audio group." if "audio" in groups else "User is not in the audio group.")),
            Check("pulse_compat", "PulseAudio compatibility", "Compatible server queryable through pactl.", lambda: warning(command_exists("pactl") and "PipeWire" in (command_output(["pactl", "info"])[1]), "PulseAudio compatibility sobre PipeWire respondeu." if command_exists("pactl") else "pactl not found; a new login may be required."), required=False),
        )
    if module == "swap":
        return (
            pkg("util-linux", "Swap utilities"),
            Check("swapfile", "Swapfile present", "/swapfile configured by the role.", lambda: result(Path("/swapfile").is_file(), "Swapfile found." if Path("/swapfile").is_file() else "Swapfile not found.")),
            Check("swap_active", "Swap active", "Swap currently available to the kernel.", swap_active_status),
            Check("fstab", "Swap registered in fstab", "Persistent entry in /etc/fstab.", lambda: result(Path("/etc/fstab").is_file() and "/swapfile" in Path("/etc/fstab").read_text(errors="replace"), "Swapfile registered." if Path("/etc/fstab").is_file() and "/swapfile" in Path("/etc/fstab").read_text(errors="replace") else "Swapfile not registered.")),
        )
    if module == "energia":
        return (
            pkg("elogind", "elogind installed"), pkg("polkit-elogind", "integrated polkit installed"),
            Check("elogind_service", "elogind active", "Session manager.", lambda: result(service_running("elogind"), "elogind is active." if service_running("elogind") else "elogind is not active.")),
            Check("polkit_service", "polkit active", "Authorization for power actions.", lambda: result(service_running("polkit"), "polkit is active." if service_running("polkit") else "polkit is not active.")),
            Check("sddm_rules", "SDDM power rules", "Backend-managed polkit rule.", lambda: result(Path("/etc/polkit-1/rules.d/49-alpine-sddm-power.rules").is_file(), "SDDM rule found." if Path("/etc/polkit-1/rules.d/49-alpine-sddm-power.rules").is_file() else "SDDM rule not found.")),
        )
    if module == "fontes":
        return (
            pkg("fontconfig", "Fontconfig instalado"), pkg("font-noto", "Noto fonts installed"), pkg("font-noto-emoji", "Emoji fonts installed"), pkg("font-noto-cjk", "CJK fonts installed"),
            Check("font_cache", "Font cache available", "fc-list can query installed fonts.", lambda: result(command_exists("fc-list") and subprocess.run(["fc-list"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False).returncode == 0, "Font cache is queryable." if command_exists("fc-list") else "fc-list not found.")),
        )
    if module == "kde":
        return (
            Check("plasma", "Plasma detected", "Plasma session or executable.", lambda: result(command_exists("plasmashell") or bool(os.environ.get("KDE_FULL_SESSION")), "Plasma detected." if command_exists("plasmashell") or os.environ.get("KDE_FULL_SESSION") else "Plasma not detected.")),
            Check("kded", "kded6 available", "KDE central service.", lambda: result(command_exists("kded6"), "kded6 available." if command_exists("kded6") else "kded6 not found.")),
            Check("systemmonitor_config", "System Monitor configured", "Role-managed configuration file.", lambda: result((home / ".config/systemmonitorrc").is_file(), "Configuration found." if (home / ".config/systemmonitorrc").is_file() else "Configuration not found."), required=False),
            Check("overview_page", "Overview page available", "System Monitor Overview page.", lambda: result((home / ".local/share/plasma-systemmonitor/overview.page").is_file(), "Overview page found." if (home / ".local/share/plasma-systemmonitor/overview.page").is_file() else "Overview page not found."), required=False),
        )
    raise ValueError(f"Unknown module: {module}")


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
    parser.add_argument("--json", action="store_true", help="kept for compatibility; JSON is the default")
    args = parser.parse_args()
    print(json.dumps(diagnose(args.module), ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
