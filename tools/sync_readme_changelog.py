"""Copies CHANGELOG.md into the Changelog section of README.md so the two never drift apart.

The README holds two markers:

    <!-- changelog:start -->
    <!-- changelog:end -->

Everything between them is rewritten. The two newest versions are shown open; older ones go in a collapsed block.
Run it from the repository root after editing CHANGELOG.md:

    python tools/sync_readme_changelog.py
"""
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
START = "<!-- changelog:start -->"
END = "<!-- changelog:end -->"
OPEN_VERSIONS = 2


def read(name):
    with open(os.path.join(ROOT, name), encoding="utf-8", newline="") as f:
        return f.read().replace("\r\n", "\n")


def versions(changelog):
    """[(version, body)] in file order. Version headings are '## <version>'."""
    parts = re.split(r"^## (.+)$", changelog, flags=re.M)
    return [(parts[i].strip(), parts[i + 1].strip("\n")) for i in range(1, len(parts) - 1, 2)]


def render(version, body):
    # '### Features' becomes a bold label so the README keeps a flat outline
    body = re.sub(r"^### (.+)$", r"**\1**", body, flags=re.M)
    return "### %s\n\n%s\n" % (version, body)


def build(changelog):
    vs = versions(changelog)
    if not vs:
        sys.exit("No '## <version>' sections found in CHANGELOG.md")
    out = [render(v, b) for v, b in vs[:OPEN_VERSIONS]]
    older = vs[OPEN_VERSIONS:]
    if older:
        names = "%s to %s" % (older[0][0], older[-1][0]) if len(older) > 1 else older[0][0]
        out.append("<details>\n<summary>Older versions (%s)</summary>\n\n%s\n</details>\n"
                   % (names, "\n".join(render(v, b) for v, b in older)))
    out.append("Full history: [CHANGELOG.md](CHANGELOG.md).\n")
    return "\n".join(out)


def main():
    readme = read("README.md")
    if START not in readme or END not in readme:
        sys.exit("README.md has no changelog markers")
    head, rest = readme.split(START, 1)
    _, tail = rest.split(END, 1)
    new = head + START + "\n\n" + build(read("CHANGELOG.md")) + "\n" + END + tail
    if new == readme:
        print("README changelog already up to date")
        return
    with open(os.path.join(ROOT, "README.md"), "w", encoding="utf-8", newline="") as f:
        f.write(new)
    print("README changelog updated")


if __name__ == "__main__":
    main()
