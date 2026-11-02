#!/usr/bin/env python3
"""Remove o painel Applications do Overview do KDE System Monitor.

O arquivo original instalado pelo KDE nunca é alterado. Uma cópia local é
criada no diretório de dados do usuário para que o override seja reversível.
"""
from __future__ import annotations

import re
import shutil
import sys
from pathlib import Path

MARKER = "# alpine-desktop: Applications panel removed for OpenRC\n"


def sections(text: str) -> list[tuple[str, str]]:
    matches = list(re.finditer(r"(?m)^((?:\[.*?\])+)$", text))
    result: list[tuple[str, str]] = []
    for index, match in enumerate(matches):
        end = matches[index + 1].start() if index + 1 < len(matches) else len(text)
        result.append((match.group(1), text[match.start():end]))
    return result


def build_override(source: Path) -> str:
    text = source.read_text(encoding="utf-8")
    parsed = sections(text)
    application_faces: set[str] = set()
    application_rows: set[str] = set()

    for header, block in parsed:
        if not header.startswith("[Face-"):
            continue
        if "chartFace=org.kde.ksysguard.applicationstable" not in block:
            continue
        face_match = re.match(r"(\[Face-[^]]+\])", header)
        if face_match:
            application_faces.add(face_match.group(1))
    for header, block in parsed:
        if not header.startswith("[page][row-"):
            continue
        if any(f"face={face[1:-1]}" in block for face in application_faces):
            row_match = re.match(r"^\[page\]\[(row-[^]]+)\]", header)
            if row_match:
                application_rows.add(row_match.group(1))

    if not application_faces:
        raise RuntimeError("Applications face not found in overview.page")

    output: list[str] = [MARKER]
    for header, block in parsed:
        if any(header.startswith(face) for face in application_faces):
            continue
        if any(header.startswith(f"[page][{row}]") for row in application_rows):
            continue
        output.append(block)
    return "".join(output)


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: remover-painel-applications.py SOURCE TARGET", file=sys.stderr)
        return 2
    source = Path(sys.argv[1])
    target = Path(sys.argv[2])
    if not source.is_file():
        raise RuntimeError(f"source not found: {source}")

    rendered = build_override(source)
    target.parent.mkdir(parents=True, exist_ok=True)
    backup = target.with_suffix(target.suffix + ".alpine-desktop.orig")
    if target.exists() and MARKER not in target.read_text(encoding="utf-8") and not backup.exists():
        shutil.copy2(target, backup)
    if target.exists() and target.read_text(encoding="utf-8") == rendered:
        print("unchanged")
        return 0
    target.write_text(rendered, encoding="utf-8")
    print("updated")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
