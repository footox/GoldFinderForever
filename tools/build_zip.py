# Builds the release zip for CurseForge or for sharing: dist/GoldFinderForever-<version>.zip with a single GoldFinderForever/
# folder that holds only what the game loads (files listed in the .toc) plus LICENSE and CHANGELOG.md.
# Usage (from the addon folder):  python -I tools/build_zip.py
import os
import re
import sys
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOC = os.path.join(ROOT, "GoldFinderForever.toc")
EXTRA = ["GoldFinderForever.toc", "LICENSE", "CHANGELOG.md"]


def main():
    text = open(TOC, encoding="utf-8").read()
    m = re.search(r"^## Version:\s*(\S+)", text, re.M)
    if not m:
        sys.exit("No '## Version:' line in GoldFinderForever.toc")
    version = m.group(1)
    files = [ln.strip() for ln in text.splitlines() if ln.strip() and not ln.startswith("#")]
    # the icons are not load files, so the .toc list does not carry them: ship the whole art/ folder
    art_dir = os.path.join(ROOT, "art")
    art = ["art/" + n for n in sorted(os.listdir(art_dir)) if os.path.isfile(os.path.join(art_dir, n))] if os.path.isdir(art_dir) else []
    icon = re.search(r"^## IconTexture:\s*(\S+)", text, re.M)
    if icon:
        p = icon.group(1).replace("\\", "/")
        marker = "interface/addons/goldfinderforever/"
        if marker in p.lower():   # a file of this addon (a built-in icon, Interface/Icons/..., needs no file)
            rel = p[p.lower().index(marker) + len(marker):]
            if rel not in files + art + EXTRA:
                sys.exit("The .toc IconTexture points at %s, which would not be in the zip" % rel)
    missing = [f for f in files + art + EXTRA if not os.path.isfile(os.path.join(ROOT, f))]
    if missing:
        sys.exit("Missing files: " + ", ".join(missing))
    out_dir = os.path.join(ROOT, "dist")
    os.makedirs(out_dir, exist_ok=True)
    out = os.path.join(out_dir, "GoldFinderForever-%s.zip" % version)
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for f in EXTRA + files + art:
            z.write(os.path.join(ROOT, f), "GoldFinderForever/" + f)
    print("zip:", out)
    print("files:", ", ".join(EXTRA + files + art))


if __name__ == "__main__":
    main()
