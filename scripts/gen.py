#!/usr/bin/env python3
"""Generate every reedmuhn-<meta> package for every distro family from meta.json.

Each meta is a list of *logical* items; meta.json's "map" turns an item into real package
names per family. An item with no mapping for a family is skipped there and reported in
MAPPING-GAPS.md, so nothing silently disappears.

Writes (per meta NAME):
  deb/reedmuhn-NAME/DEBIAN/control          rpm/reedmuhn-NAME.spec
  arch/reedmuhn-NAME/PKGBUILD               chimera/user/reedmuhn-NAME/template.py
  alpine/reedmuhn-NAME/APKBUILD
  app-metapackages/reedmuhn-NAME/   (Gentoo ebuild + metadata.xml)
Run:  python3 scripts/gen.py
"""
import json
import pathlib
import shutil

ROOT = pathlib.Path(__file__).resolve().parent.parent
M = json.loads((ROOT / "meta.json").read_text())
VER = (ROOT / "VERSION").read_text().strip()
MAINT = M["maintainer"]
FAMS = ["deb", "rpm", "opensuse", "arch", "gentoo", "chimera", "alpine", "void"]
REPO_PKG = "reedmuhn-cider-repo"
gaps = {}


def put(path, text):
    p = ROOT / path
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(text)


def deb_origins():
    """deb/package-sources.conf -> {package: origin}. Packages not listed come from Debian main."""
    out = {}
    conf = ROOT / "deb" / "package-sources.conf"
    for line in conf.read_text().splitlines():
        line = line.split("#", 1)[0].split()
        if len(line) >= 2:
            out[line[0]] = line[1]
    return out


DEB_ORIGIN = deb_origins()


def names(item, fam):
    return M["map"].get(item, {}).get(fam) or []


def resolve(meta, fam):
    """-> (hard, soft, use) lists of package names for this family."""
    hard, soft, use = [], [], {}
    for item in M["metas"][meta]["items"]:
        pk = names(item, fam)
        if not pk:
            gaps.setdefault(f"reedmuhn-{meta}", {}).setdefault(item, []).append(fam)
            continue
        if fam == "gentoo" and item in M.get("gentoo_use", []):
            use[item] = pk
        elif item in M.get("soft", {}).get(fam, []):
            soft += pk
        else:
            hard += pk
    return hard, soft, use


# stale generated output from earlier layouts / removed metas
for sub in ["deb", "arch", "chimera/user", "alpine", "void/srcpkgs", "opensuse", "app-metapackages"]:
    for old in (ROOT / sub).glob("reed*-meta*"):
        shutil.rmtree(old, ignore_errors=True)
for sub in ["deb", "arch", "chimera/user", "alpine", "void/srcpkgs", "opensuse", "app-metapackages"]:
    for old in (ROOT / sub).glob("reedmuhn-*"):
        if old.name != REPO_PKG and old.name[len("reedmuhn-"):] not in M["metas"]:
            shutil.rmtree(old, ignore_errors=True)
for old in (ROOT / "rpm").glob("reedmuhn-*.spec"):
    if old.stem != REPO_PKG and old.stem[len("reedmuhn-"):] not in M["metas"]:
        old.unlink()

for meta, spec in M["metas"].items():
    name, summary = f"reedmuhn-{meta}", spec["summary"]
    repo_fams = set(spec.get("needs_repo", []))  # families that still add Cider's own repo

    # ---- deb ----
    hard, soft, _ = resolve(meta, "deb")
    dep = ([f"{REPO_PKG} (>= 1.0)"] if "deb" in repo_fams else []) + hard
    c = ["Package: " + name, f"Version: {VER}", "Architecture: all", "Section: misc",
         "Priority: optional", f"Maintainer: {MAINT}"]
    if dep:
        c.append("Depends: " + ", ".join(dep))
    if soft:
        c.append("Recommends: " + ", ".join(soft))
    # Say where each non-default dependency comes from, so `apt show` tells the truth.
    from_repo = [d for d in hard if DEB_ORIGIN.get(d) in ("built", "upstream")]
    from_contrib = [d for d in hard if DEB_ORIGIN.get(d, "").startswith("contrib")]
    needs_i386 = [d for d in hard if DEB_ORIGIN.get(d) == "contrib+i386"]
    c += [f"Description: {summary}", " Metapackage: contains no files, only dependencies.",
          " .",
          " Every dependency comes from the Debian archive"
          + (", except as noted below." if (from_repo or from_contrib or needs_i386) else ".")]
    if from_repo:
        c += [" .", " Built by this repository (scripts/build-deb.sh): " + ", ".join(from_repo) + "."]
    if from_contrib:
        c += [" .", " Needs the Debian contrib component: " + ", ".join(from_contrib) + "."]
    if needs_i386:
        c += [" .", " " + ", ".join(needs_i386) + " also needs the i386 architecture."
              " Run scripts/enable-steam-prereqs.sh before installing."]
    if soft:
        c += [" .", " Cider is recommended from its upstream repository when available."]
    put(f"deb/{name}/DEBIAN/control", "\n".join(c) + "\n")

    # ---- RPM families: Fedora and openSUSE Tumbleweed ----
    for fam, outdir in (("rpm", "rpm"), ("opensuse", "opensuse")):
        hard, _, _ = resolve(meta, fam)
        req = ([REPO_PKG] if fam in repo_fams else []) + hard
        put(f"{outdir}/{name}.spec", f"""Name:           {name}
Version:        {VER}
Release:        1%{{?dist}}
Summary:        {summary}
License:        MIT
BuildArch:      noarch
""" + "".join(f"Requires:       {x}\n" for x in req) + f"""
%description
Metapackage: contains no applications, only dependencies.

%prep
%build
%install
mkdir -p %{{buildroot}}%{{_docdir}}/{name}
echo "{name} {VER}" > %{{buildroot}}%{{_docdir}}/{name}/VERSION

%files
%{{_docdir}}/{name}/VERSION

%changelog
* Sun Nov 15 2026 Reedman27 <213130028+Reedman27@users.noreply.github.com> - {VER}-1
- Metapackage generated from meta.json
""")

    # ---- arch ----
    hard, _, _ = resolve(meta, "arch")
    dp = ([REPO_PKG] if "arch" in repo_fams else []) + hard
    deps = "(" + " ".join(repr(x) for x in dp) + ")" if dp else "()"
    put(f"arch/{name}/PKGBUILD", f"""# Maintainer: {MAINT}
pkgname={name}
pkgver={VER}
pkgrel=1
pkgdesc="{summary}"
arch=('any')
license=('MIT')
depends={deps}

package() {{
	install -dm755 "$pkgdir/usr/share/doc/$pkgname"
	echo "$pkgname $pkgver" > "$pkgdir/usr/share/doc/$pkgname/VERSION"
}}
""")

    # ---- gentoo ----
    hard, _, use = resolve(meta, "gentoo")
    flags = " ".join("+" + u for u in use)
    body = "".join(f"\t{u}? ( {' '.join(p)} )\n" for u, p in use.items()) + "".join(f"\t{x}\n" for x in hard)
    put(f"app-metapackages/{name}/{name}-{VER}.ebuild", f"""# Generated by scripts/gen.py, do not hand-edit
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="{summary}"
HOMEPAGE="https://github.com/Reedman27"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"
{f'IUSE="{flags}"' if flags else ''}

RDEPEND="
{body}"
""")
    uf = "".join(f'\t\t<flag name="{u}">Also install {" ".join(p)}</flag>\n' for u, p in use.items())
    put(f"app-metapackages/{name}/metadata.xml", f"""<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE pkgmetadata SYSTEM "https://www.gentoo.org/dtd/metadata.dtd">
<pkgmetadata>
	<maintainer type="person">
		<email>213130028+Reedman27@users.noreply.github.com</email>
		<name>Reedman27</name>
	</maintainer>
	<longdescription>{summary}. Contains no files, only dependencies.</longdescription>
{f'	<use>{chr(10)}{uf}	</use>{chr(10)}' if uf else ''}</pkgmetadata>
""")

    # ---- chimera ----
    hard, _, _ = resolve(meta, "chimera")
    put(f"chimera/user/{name}/template.py", f'''pkgname = "{name}"
pkgver = "{VER}"
pkgrel = 0
build_style = "meta"
depends = {json.dumps(hard)}
pkgdesc = "{summary}"
license = "custom:meta"
url = "https://github.com/Reedman27"
''')

    # ---- alpine ----
    hard, _, _ = resolve(meta, "alpine")
    put(f"alpine/{name}/APKBUILD", f"""# Maintainer: {MAINT}
pkgname={name}
pkgver={VER}
pkgrel=0
pkgdesc="{summary}"
url="https://github.com/Reedman27"
arch="noarch"
license="MIT"
depends="{' '.join(hard)}"
options="!check"

package() {{
\tmkdir -p "$pkgdir"
}}
""")

    # ---- Void Linux (XBPS source templates) ----
    hard, _, _ = resolve(meta, "void")
    depstr = " ".join(hard)
    put(f"void/srcpkgs/{name}/template", f"""# Template file for '{name}'
pkgname={name}
version={VER}
revision=1
metapackage=yes
short_desc=\"{summary}\"
maintainer=\"{MAINT}\"
license=MIT
homepage=https://github.com/Reedman27
depends=\"{depstr}\"
""")

# ---- report what could not be mapped ----
lines = ["# Mapping gaps (generated)", "",
         "Items skipped because meta.json has no package name for that distro family.",
         "Hosted desktop applications are built per package family; all other meta contents come from the",
         "distro's own repos, so a gap here is software the distro does not ship or a",
         "package name that could not be confirmed.", ""]
for pkg, items in sorted(gaps.items()):
    lines.append(f"## {pkg}")
    for item, fams in items.items():
        lines.append(f"- `{item}`: {', '.join(fams)}")
    lines.append("")
put("MAPPING-GAPS.md", "\n".join(lines))

# Generate a human-readable inventory for the Chimera cports overlay.
import ast
chimera_entries = []
for template_path in sorted((ROOT / "chimera" / "user").glob("*/template.py")):
    tree = ast.parse(template_path.read_text(), filename=str(template_path))
    values = {}
    for node in tree.body:
        if isinstance(node, ast.Assign) and len(node.targets) == 1 and isinstance(node.targets[0], ast.Name):
            try:
                values[node.targets[0].id] = ast.literal_eval(node.value)
            except Exception:
                pass
    chimera_entries.append((
        values.get("pkgname", template_path.parent.name),
        values.get("pkgver", "?"),
        values.get("pkgdesc", ""),
        values.get("broken"),
        template_path.relative_to(ROOT).as_posix(),
    ))
index = [
    "# ReedMuhn Chimera cports package index", "",
    "This inventory describes the cports templates in this repository's `chimera/user/` tree. It is not the official Chimera APK index; packages enter the official index only after cports review, merge, and successful project builds.", "",
    "| Package | Version | Status | Description |", "|---|---:|---|---|",
]
for pkg, ver, desc, broken, path in chimera_entries:
    status = "blocked" if broken else "template"
    index.append(f"| [`{pkg}`]({path}) | `{ver}` | {status} | {desc} |")
index.extend([
    "", "## Window Maker meta-package", "",
    "`reedmuhn-wmaker` currently resolves to the following Chimera packages:", "",
])
wm_template = ROOT / "chimera" / "user" / "reedmuhn-wmaker" / "template.py"
wm_values = {}
for node in ast.parse(wm_template.read_text()).body:
    if isinstance(node, ast.Assign) and len(node.targets) == 1 and isinstance(node.targets[0], ast.Name):
        try:
            wm_values[node.targets[0].id] = ast.literal_eval(node.value)
        except Exception:
            pass
for dep in wm_values.get("depends", []):
    index.append(f"- `{dep}`")
index.extend([
    "", "## Not yet in the Chimera meta-package", "",
    "`wmclock`, `wmmon` and `wmsystemtray` are not in cports yet and are left out of the Chimera meta-package. The hosted templates (`windowmaker`, `wm-desktop`, `wmvol`, `wmmedia`, `rustcord`) are separate packages: build them with `chimera/setup.sh` and install them next to the meta-package.",
])
put("chimera/INDEX.md", "\n".join(index) + "\n")
print(f"generated {len(M['metas'])} metas ({', '.join(M['metas'])}) v{VER}; gaps in MAPPING-GAPS.md")
