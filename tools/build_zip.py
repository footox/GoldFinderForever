# Builds the release zip for CurseForge or for sharing: dist/GoldFinder-<version>.zip with a single GoldFinder/
# folder that holds only what the game loads (files listed in the .toc) plus LICENSE and CHANGELOG.md.
# Usage (from the addon folder):  python -I tools/build_zip.py
import os
import re
import sys
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOC = os.path.join(ROOT, "GoldFinder.toc")
EXTRA = ["GoldFinder.toc", "LICENSE", "CHANGELOG.md"]


def main():
    text = open(TOC, encoding="utf-8").read()
    m = re.search(r"^## Version:\s*(\S+)", text, re.M)
    if not m:
        sys.exit("No '## Version:' line in GoldFinder.toc")
    version = m.group(1)
    files = [ln.strip() for ln in text.splitlines() if ln.strip() and not ln.startswith("#")]
    missing = [f for f in files + EXTRA if not os.path.isfile(os.path.join(ROOT, f))]
    if missing:
        sys.exit("Missing files: " + ", ".join(missing))
    out_dir = os.path.join(ROOT, "dist")
    os.makedirs(out_dir, exist_ok=True)
    out = os.path.join(out_dir, "GoldFinder-%s.zip" % version)
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for f in EXTRA + files:
            z.write(os.path.join(ROOT, f), "GoldFinder/" + f)
    print("zip:", out)
    print("files:", ", ".join(EXTRA + files))


if __name__ == "__main__":
    main()
