# patches/

Changes to upstream source, kept as patch files.

The build unpacks each release tarball, then applies every `*.patch` file in
`patches/<component>/` (`kernel`, `glibc`, `busybox`, `binutils`, `gcc`,
`tcc`, `make`), in name order, before compiling. `patches/lfs/` works a little
differently; see the end of this file.
Because the changes live here instead of only in the build directory, they're
saved in git, show up in pull requests, and survive `./laker clean` and
version upgrades.

You don't usually write these by hand:

```sh
./laker shell                         # edit files under /build/src/..., then exit
./laker diff kernel                   # review what you changed
./laker diff kernel hello-message     # save it as patches/kernel/NNNN-hello-message.patch
git add patches && git commit
```

To share a patch, commit it. Anyone who pulls it gets it applied on their next
build. A patch made for one kernel version may not apply to another; the build
stops and names the patch if that happens.

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

See "Changing an LFS package's source" in the main README for the whole workflow. The book's own
patches (in `lfs/book/wget-list-sysv`) aren't here: each step applies those
itself, as the book does.
