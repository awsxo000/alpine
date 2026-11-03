#!/usr/bin/env python3
"""Consulta e migra somente o canal Stable do Nix usado pelo projeto."""
from __future__ import annotations

import json
import re
import subprocess
import sys
import urllib.error
import urllib.request
from urllib.parse import urlencode
from pathlib import Path

STATUS_URL = "https://status.nixos.org/"
PROMETHEUS_URL = "https://prometheus.nixos.org/api/v1/query"
CHANNEL_BASE = "https://nixos.org/channels/nixos-{}"
STATE_FILE = Path(__file__).resolve().parents[2] / ".alpine-state" / "vars.yml"


def current_channel() -> tuple[str | None, str | None]:
    try:
        output = subprocess.run(["nix-channel", "--list"], text=True, capture_output=True, check=False).stdout
    except OSError:
        return None, None
    for line in output.splitlines():
        match = re.search(r"^\s*nixpkgs\s+https?://[^ ]*/nixos-(\d+\.\d+)\s*$", line)
        if match:
            return match.group(1), line.strip()
    return None, None


def latest_stable() -> tuple[str | None, str | None]:
    query = urlencode({"query": "channel_revision"})
    request = urllib.request.Request(f"{PROMETHEUS_URL}?{query}", headers={"User-Agent": "Alpine-Desktop-Center/stable-channel-check"})
    with urllib.request.urlopen(request, timeout=15) as response:
        payload = json.loads(response.read().decode("utf-8"))
    candidates = set()
    for record in payload.get("data", {}).get("result", []):
        metric = record.get("metric", {})
        channel = str(metric.get("channel", ""))
        status = str(metric.get("status", "")).lower()
        match = re.fullmatch(r"nixos-(\d+\.\d+)", channel)
        if match and status == "stable":
            candidates.add(match.group(1))
    if not candidates:
        return None, None
    version = max(candidates, key=lambda item: tuple(int(part) for part in item.split(".")))
    return version, CHANNEL_BASE.format(version)


def report() -> dict[str, object]:
    current, current_line = current_channel()
    try:
        latest, url = latest_stable()
        if not latest:
            return {"status": "unknown", "message": "Nenhum canal Stable foi encontrado na fonte oficial."}
        return {
            "status": "update_available" if current != latest else "current",
            "current_version": current,
            "current_channel": current_line,
            "latest_version": latest,
            "latest_channel": url,
            "source": STATUS_URL,
        }
    except (OSError, urllib.error.URLError, ValueError) as exc:
        return {"status": "unknown", "message": f"Não foi possível consultar os canais Stable: {exc}"}


def migrate() -> int:
    result = report()
    if result.get("status") == "unknown":
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return 1
    latest = str(result["latest_version"])
    current = result.get("current_version")
    if current == latest:
        print(json.dumps(result, ensure_ascii=False, indent=2))
        print(f"Canal Stable já está em nixos-{latest}.")
        return 0
    url = CHANNEL_BASE.format(latest)
    print(f"==> Migrando o canal Stable: nixos-{current or 'desconhecido'} -> nixos-{latest}")
    subprocess.run(["nix-channel", "--add", url, "nixpkgs"], check=True)
    subprocess.run(["nix-channel", "--update", "nixpkgs"], check=True)
    STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    lines = STATE_FILE.read_text(encoding="utf-8").splitlines() if STATE_FILE.exists() else ["---"]
    replaced = False
    for index, line in enumerate(lines):
        if line.startswith("nix_canal_versao:"):
            lines[index] = f'nix_canal_versao: "{latest}"'
            replaced = True
    if not replaced:
        lines.append(f'nix_canal_versao: "{latest}"')
    STATE_FILE.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")
    print(f"Canal Stable atualizado para nixos-{latest}.")
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 2 or sys.argv[1] not in {"verificar", "migrar"}:
        raise SystemExit("Uso: canal-stable-nix.py verificar|migrar")
    if sys.argv[1] == "verificar":
        print(json.dumps(report(), ensure_ascii=False, indent=2))
        raise SystemExit(0)
    raise SystemExit(migrate())
