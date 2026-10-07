#!/usr/bin/env python3
"""Generate LakerLinux's LFS build scripts from the Linux From Scratch book.

    tools/extract-book.py LFS-BOOK-12.4-NOCHUNKS.html wget-list-sysv OUTDIR

writes one shell script per book section (chapters 5 to 8) into OUTDIR,
containing that section's commands, in order, minus its test-suite commands.
Each script starts with a header naming the section, its page in the online
book, and the package tarball it builds (if any).

The scripts in lfs/ were generated this way and then edited by hand where
LakerLinux differs from the book (see the "LakerLinux:" comments in them).
To move to a new LFS release, generate into a scratch directory and compare.
"""
import html
import os
import re
import sys

BOOK_URL = "https://www.linuxfromscratch.org/lfs/view/12.4"

# Book chapter -> output directory, and which section ids belong to it.
CHAPTERS = [
    ("5-cross-toolchain", "chapter05", re.compile(r"^ch-tools-(binutils-pass1|gcc-pass1|linux-headers|glibc|libstdcpp)$")),
    ("6-temporary-tools", "chapter06", None),   # ch-tools-* sections between 6.2 and 6.18
    ("7-chroot",          "chapter07", None),   # ch-tools-* sections from 7.5 on
    ("8-system",          "chapter08", re.compile(r"^ch-system-")),
]

# Commands that only run test suites. A block containing any of these is
# left out (LFS marks test suites as optional; they take hours).
TEST_MARKERS = [
    "make check", "make -k check", "make test", "make -k test", "make tests",
    "su tester", "chown -R tester", "TESTSUITEFLAGS", "test_summary",
    "ninja test", "make -k -j", "runtest", "pytest", "make RUN_EXPENSIVE",
    "ulimit -s", "LC_ALL=en_US.UTF-8 make check",
]


def sections(src):
    heads = [(m.start(), m.group(1), m.group(2)) for m in
             re.finditer(r'<h2 class="title">\s*<a id="([^"]+)"[^>]*>(.*?)</h2>', src, re.S)]
    heads.append((len(src), None, ""))
    for (pos, sid, raw), (nxt, _, _) in zip(heads, heads[1:]):
        title = " ".join(html.unescape(re.sub(r"<[^>]+>", "", raw)).split())
        blocks = [html.unescape(re.sub(r"<[^>]+>", "", b)).rstrip()
                  for b in re.findall(r'<pre class="userinput">(.*?)</pre>', src[pos:nxt], re.S)]
        yield sid, title, blocks


def norm(s):
    return re.sub(r"[^a-z0-9]", "", s.lower())


def tarball_for(title, files):
    """'5.2. Binutils-2.45 - Pass 1' -> 'binutils-2.45.tar.xz'."""
    name = re.sub(r"^[0-9.]+\s+", "", title)
    name = re.sub(r"\s+-\s+Pass\s+\d+$", "", name)
    if " from " in name:
        name = name.split(" from ", 1)[1]
    name = norm(name.split(" ")[0])
    tarballs = [f for f in files if not f.endswith(".patch")]
    hits = [f for f in tarballs if norm(f).startswith(name)]
    return min(hits, key=len) if hits else None


def chapter_of(sid, number):
    for outdir, chapdir, pat in CHAPTERS:
        if pat and pat.match(sid):
            return outdir, chapdir
    if sid.startswith("ch-tools-"):
        major, minor = (int(x) for x in number.split(".")[:2])
        if major == 6 and minor >= 2:
            return "6-temporary-tools", "chapter06"
        if major == 7 and minor >= 5:
            return "7-chroot", "chapter07"
    return None, None


def main():
    book, wget_list, outroot = sys.argv[1:4]
    src = open(book, encoding="utf-8").read()
    files = [line.strip().rsplit("/", 1)[-1] for line in open(wget_list) if line.strip()]
    counters = {}
    for sid, title, blocks in sections(src):
        m = re.match(r"^(\d+\.\d+)\.\s", title)
        if not m or not blocks:
            continue
        outdir, chapdir = chapter_of(sid, m.group(1))
        if not outdir:
            continue
        page = sid.split("-", 2)[2]          # ch-tools-binutils-pass1 -> binutils-pass1
        kept = [b for b in blocks if not any(t in b for t in TEST_MARKERS)]
        dropped = len(blocks) - len(kept)
        pkg = tarball_for(title, files) if not sid.endswith(("-cleanup", "-stripping", "-creatingdirs",
                                                              "-createfiles", "-pkgmgt")) else None
        counters[outdir] = counters.get(outdir, 0) + 1
        fname = f"{counters[outdir]:02d}-{page.lower()}.sh"
        os.makedirs(os.path.join(outroot, outdir), exist_ok=True)
        with open(os.path.join(outroot, outdir, fname), "w") as f:
            f.write(f"# LFS 12.4, {title}\n")
            f.write(f"# {BOOK_URL}/{chapdir}/{page.lower()}.html\n")
            f.write(f"# Package: {pkg or '(none)'}\n")
            if dropped:
                f.write(f"# ({dropped} test-suite command block(s) from the book left out.)\n")
            f.write("\n" + "\n\n".join(kept) + "\n")
        print(f"{outdir}/{fname:40s} {pkg or '-'}")


if __name__ == "__main__":
    main()
