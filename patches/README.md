# patches/

Changes to upstream source, kept as patch files so they're saved in git, show
up in pull requests, and are applied automatically on every build.

## `patches/kernel/`

Applied to the kernel source, in name order, after it's unpacked. You don't
usually write these by hand:

```sh
./laker shell                         # edit files under /build/src/linux-*, then exit
./laker diff kernel                   # review what you changed
./laker diff kernel hello-message     # save it as patches/kernel/NNNN-hello-message.patch
git add patches && git commit
```

The text above the first `diff --git` line in a patch is a description for
people to read. The build ignores it.

## `patches/lfs/<package>/`

Applied to a Linux From Scratch package when its step unpacks it, before the
book's commands run. `<package>` is the tarball's name without `.tar.*` (or
`.tgz`), e.g. `patches/lfs/grep-3.12/`. Patches are applied with
`patch -Np1`, so make them from the directory above the source tree:

```sh
diff -Naur grep-3.12.orig grep-3.12 > 0001-my-change.patch
```

See "Changing things" in the main README for the whole workflow. The book's own
patches (in `lfs/book/wget-list-sysv`) aren't here: each step applies those
itself, as the book does.
