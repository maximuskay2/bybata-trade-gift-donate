#!/usr/bin/env python3
"""Migrate ScaffoldMessenger SnackBar calls to AppToast in lib/."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "lib"
IMPORT = "import 'package:bybata/core/widgets/app_toast.dart';"
IMPORT_REL_CANDIDATES = [
    "import '../../../core/widgets/app_toast.dart';",
    "import '../../../../core/widgets/app_toast.dart';",
    "import '../../core/widgets/app_toast.dart';",
    "import '../core/widgets/app_toast.dart';",
    "import 'package:bybata/core/widgets/app_toast.dart';",
]

SKIP = {"app_toast.dart", "comments_section.dart", "settings_ui.dart"}


def infer_type(block: str) -> str:
    lower = block.lower()
    if "colors.green" in lower or "successscolor" in lower or "apptheme.success" in lower:
        return "success"
    if "colors.red" in lower or "error" in lower and "backgroundcolor" in lower:
        return "error"
    if "colors.orange" in lower or "warning" in lower:
        return "warning"
    return "info"


def extract_text_expr(block: str) -> str | None:
    m = re.search(r"content:\s*Text\(\s*'((?:\\'|[^'])*)'\s*\)", block, re.DOTALL)
    if m:
        return f"'{m.group(1)}'"
    m = re.search(r'content:\s*Text\(\s*"((?:\\"|[^"])*)"\s*\)', block, re.DOTALL)
    if m:
        return f'"{m.group(1)}"'
    m = re.search(r"content:\s*Text\(([^)]+)\)", block, re.DOTALL)
    if m:
        return m.group(1).strip()
    return None


def ensure_import(content: str, filepath: Path) -> str:
    if "app_toast.dart" in content:
        return content
    lines = content.splitlines(keepends=True)
    last_import = 0
    for i, line in enumerate(lines):
        if line.startswith("import "):
            last_import = i
    insert = IMPORT + "\n"
    if last_import == 0 and lines and not lines[0].startswith("import "):
        return insert + content
    lines.insert(last_import + 1, insert)
    return "".join(lines)


def migrate_file(path: Path) -> bool:
    if path.name in SKIP:
        return False
    original = path.read_text(encoding="utf-8")
    content = original

    pattern = re.compile(
        r"ScaffoldMessenger\.of\((context|[^)]+)\)\.showSnackBar\(\s*"
        r"(const\s+)?SnackBar\((.*?)\)\s*,?\s*\)\s*;",
        re.DOTALL,
    )

    changed = False

    def repl(match: re.Match[str]) -> str:
        nonlocal changed
        ctx = match.group(1).strip()
        block = match.group(3)
        msg = extract_text_expr(block)
        if not msg:
            return match.group(0)
        toast_type = infer_type(block)
        method = {
            "success": "success",
            "error": "error",
            "warning": "warning",
            "info": "show",
        }[toast_type]
        changed = True
        if method == "show":
            return f"AppToast.show({ctx}, {msg});"
        return f"AppToast.{method}({ctx}, {msg});"

    content = pattern.sub(repl, content)

    # One-line SnackBar without trailing semicolon on same pattern (arrow functions)
    pattern2 = re.compile(
        r"ScaffoldMessenger\.of\((context|[^)]+)\)\.showSnackBar\(\s*"
        r"(const\s+)?SnackBar\(content:\s*Text\(([^)]+)\)(?:,\s*backgroundColor:\s*[^)]+)?\)\s*\)",
    )

    def repl2(match: re.Match[str]) -> str:
        nonlocal changed
        ctx = match.group(1).strip()
        msg = match.group(3).strip()
        full = match.group(0)
        toast_type = infer_type(full)
        method = {
            "success": "success",
            "error": "error",
            "warning": "warning",
            "info": "show",
        }[toast_type]
        changed = True
        if method == "show":
            return f"AppToast.show({ctx}, {msg})"
        return f"AppToast.{method}({ctx}, {msg})"

    content = pattern2.sub(repl2, content)

    if not changed:
        return False

    content = ensure_import(content, path)
    if content != original:
        path.write_text(content, encoding="utf-8")
        return True
    return False


def main() -> None:
    updated = []
    for path in sorted(ROOT.rglob("*.dart")):
        if migrate_file(path):
            updated.append(str(path.relative_to(ROOT.parent)))
    print(f"Updated {len(updated)} files")
    for p in updated:
        print(f"  - {p}")


if __name__ == "__main__":
    main()
