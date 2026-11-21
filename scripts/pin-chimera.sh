#!/bin/sh
# Fill in or verify the source checksums of the Chimera cports templates.
#
#   scripts/pin-chimera.sh              fill every all-zero sha256 placeholder
#   scripts/pin-chimera.sh --check      download every source and compare (no changes)
#   scripts/pin-chimera.sh --force PKG  re-pin PKG (after you changed _commit/pkgver)
#
# Needs network access to github.com (the build sandboxes of cbuild have none, so this is
# the one place that downloads). Commit the result.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
exec python3 -I - "$ROOT" "$@" <<'PYCODE'
import ast, hashlib, pathlib, re, subprocess, sys, tempfile

root = pathlib.Path(sys.argv[1])
args = sys.argv[2:]
check = "--check" in args
force = set()
if "--force" in args:
    force = set(args[args.index("--force") + 1:])
ZERO = "0" * 64
bad = 0

def load(path):
    """Evaluate only the plain top-level assignments of a template (no defs, no hooks)."""
    env = {}
    for node in ast.parse(path.read_text()).body:
        if isinstance(node, ast.Assign):
            code = compile(ast.Module([node], []), str(path), "exec")
            try:
                exec(code, {"__builtins__": {"list": list}}, env)
            except Exception:
                pass
    return env

for path in sorted((root / "chimera" / "user").glob("*/template.py")):
    if path.parent.is_symlink():
        continue
    env = load(path)
    src, old = env.get("source"), env.get("sha256")
    if not src or not old:
        continue
    name = env["pkgname"]
    if not check and not (old == ZERO or name in force):
        continue
    with tempfile.NamedTemporaryFile() as tmp:
        r = subprocess.run(["curl", "-fsSL", "--retry", "3", "-o", tmp.name, src])
        if r.returncode:
            print(f"{name}: download failed: {src}", file=sys.stderr)
            bad += 1
            continue
        new = hashlib.sha256(pathlib.Path(tmp.name).read_bytes()).hexdigest()
    if check:
        status = "ok" if new == old else f"MISMATCH (template {old[:12]}.., upstream {new[:12]}..)"
        print(f"{name}: {status}")
        bad += new != old
    else:
        path.write_text(re.sub(r'(?m)^sha256 = "[0-9a-f]{64}"', f'sha256 = "{new}"', path.read_text()))
        print(f"{name}: pinned {new}")
sys.exit(1 if bad else 0)
PYCODE
