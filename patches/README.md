# patches/

Changes to the kernel and BusyBox source, kept as patch files.

The build unpacks each release tarball, then applies every `*.patch` file in
`patches/kernel/` or `patches/busybox/`, in name order, before compiling.
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
