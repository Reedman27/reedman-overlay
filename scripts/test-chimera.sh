#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
python3 - "$ROOT" <<'PYCODE'
import ast
import os
import pathlib
import re
import sys
root = pathlib.Path(sys.argv[1])
base = root / "chimera" / "user"
errors, warnings = [], []
strict = os.environ.get("CHIMERA_STRICT") == "1"
cports = pathlib.Path(os.environ["CPORTS"]) if os.environ.get("CPORTS") else None
for path in sorted(base.glob("*/template.py")):
    if path.parent.is_symlink():
        continue
    text = path.read_text()
    try:
        tree = ast.parse(text, filename=str(path))
    except SyntaxError as exc:
        errors.append(f"{path}: Python syntax: {exc}")
        continue
    values = {}
    for node in tree.body:
        if isinstance(node, ast.Assign) and len(node.targets) == 1 and isinstance(node.targets[0], ast.Name):
            try:
                values[node.targets[0].id] = ast.literal_eval(node.value)
            except Exception:
                pass
    if values.get("pkgname") != path.parent.name:
        errors.append(f"{path}: pkgname must match directory {path.parent.name}")
    for key in ("pkgver", "pkgrel", "license"):
        if key not in values:
            errors.append(f"{path}: missing {key}")
    if values.get("build_style") == "meta" and values.get("license") != "custom:meta":
        errors.append(f"{path}: cports metapackages must use license=custom:meta")
    if "source" in values and not values.get("sha256"):
        errors.append(f"{path}: source archive has no SHA-256")
    sha = values.get("sha256")
    if isinstance(sha, str) and not re.fullmatch(r"[0-9a-f]{64}", sha):
        errors.append(f"{path}: SHA-256 must be 64 lowercase hex characters")
    elif sha == "0" * 64 and "broken" not in values:
        msg = f"{path}: sha256 not pinned yet; run scripts/pin-chimera.sh"
        (errors if strict else warnings).append(msg)
    if re.search(r"(?m)^maintainer\s*=", text):
        errors.append(f"{path}: cports has no 'maintainer' variable; cbuild lint rejects it")
    for sub in re.findall(r'@subpackage\("([^"]+)"\)', text):
        link = base / sub
        if not (link.is_symlink() and link.readlink().name == path.parent.name):
            errors.append(f"{path}: subpackage {sub} needs a symlink chimera/user/{sub} -> {path.parent.name}")
    if cports:
        for dep in list(values.get("depends", [])) + list(values.get("makedepends", [])) + list(values.get("hostmakedepends", [])):
            dep = re.split(r"[<>=~]", dep)[0]
            if dep.startswith(("so:", "cmd:", "pc:")):
                continue
            if not any((cports / cat / dep).exists() for cat in ("main", "user")) and not (base / dep).exists():
                errors.append(f"{path}: dependency '{dep}' is not in cports main/user or this repo")
if warnings:
    print("\n".join("warning: " + w for w in warnings), file=sys.stderr)
if errors:
    print("\n".join(errors), file=sys.stderr)
    sys.exit(1)
print(f"Validated {len(list(base.glob('*/template.py')))} Chimera cports templates")
PYCODE
