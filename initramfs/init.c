/*
 * LakerLinux's initramfs: the first program the kernel runs.
 *
 * The kernel has a tiny file system built in (the initramfs), holding just
 * this program as /init. Its one job is to find the real root file system,
 * mount it, and hand over to the real init (/sbin/init) there:
 *
 *   1. Mount /dev, /proc and /sys, to see the disks the kernel has found.
 *   2. Look for the partition named "lakerroot" in its disk's partition table
 *      (GPT). USB disks can take a few seconds to appear, so keep looking.
 *   3. If there's more than one (two LakerLinux USB sticks plugged in), ask
 *      which to start.
 *   4. Mount it on /newroot, make it the root directory, and run its
 *      /sbin/init, which takes over as process 1.
 *
 * Kernel command line options it understands (see "The initramfs" in
 * README.md):
 *   root=/dev/sdb2        use this partition instead of looking for one
 *   root=PARTLABEL=NAME   look for a partition with this name instead
 *   rootfstype=ext4       its file system type (default: try them all)
 *   rw / ro               mount it read-write / read-only (the default)
 *   init=/bin/sh          run this instead of /sbin/init
 *
 * It's built as a static program (no shared libraries needed), because the
 * initramfs holds nothing else. See initramfs/files.list and stage_kernel in
 * scripts/build.sh.
 */
#define _GNU_SOURCE
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mount.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>

#define NEWROOT "/newroot"
#define MAX_FOUND 16
#define MAX_CONSOLES 8
#define CHOOSE_SECONDS 10

/* Kernel command line settings. */
static char root_dev[256];                   /* root=/dev/... */
static char root_label[64] = "lakerroot";    /* root=PARTLABEL=... */
static char root_fstype[32];                 /* rootfstype= */
static int root_rw;                          /* rw */
static char init_path[256] = "/sbin/init";   /* init= */

/* Every console the kernel writes to (console= on the command line), so
 * messages and questions reach a monitor *and* a serial port. */
static int consoles[MAX_CONSOLES];
static int nconsoles;

static void say(const char *fmt, ...)
{
    char buf[1024];
    va_list ap;
    int n, i;

    n = snprintf(buf, sizeof buf, "laker-init: ");
    va_start(ap, fmt);
    n += vsnprintf(buf + n, sizeof buf - n, fmt, ap);
    va_end(ap);
    if (n >= (int)sizeof buf - 1)
        n = sizeof buf - 2;
    buf[n++] = '\n';
    if (nconsoles == 0) {
        if (write(2, buf, n) < 0) { /* nowhere else to report it */ }
        return;
    }
    for (i = 0; i < nconsoles; i++)
        if (write(consoles[i], buf, n) < 0) { /* a console we can't use */ }
}

/* Something went wrong that we can't fix: say so and stop. (If this program
 * exited, the kernel would panic with a much less helpful message.) */
static void fail(const char *fmt, ...)
{
    char buf[512];
    va_list ap;

    va_start(ap, fmt);
    vsnprintf(buf, sizeof buf, fmt, ap);
    va_end(ap);
    say("%s", buf);
    say("Can't start LakerLinux. Press Ctrl-Alt-Del to restart.");
    for (;;)
        pause();
}

static void sleep_ms(long ms)
{
    struct timespec ts = { ms / 1000, (ms % 1000) * 1000000L };
    nanosleep(&ts, NULL);
}

/* Read a small file into buf, without its trailing newline. */
static int read_file(const char *path, char *buf, size_t size)
{
    int fd = open(path, O_RDONLY | O_CLOEXEC);
    ssize_t n;

    if (fd < 0)
        return -1;
    n = read(fd, buf, size - 1);
    close(fd);
    if (n < 0)
        return -1;
    buf[n] = '\0';
    while (n > 0 && (buf[n - 1] == '\n' || buf[n - 1] == ' '))
        buf[--n] = '\0';
    return 0;
}

static void mount_or_fail(const char *src, const char *dir, const char *type)
{
    mkdir(dir, 0755);
    if (mount(src, dir, type, MS_NOSUID | MS_NOEXEC, NULL) < 0 && errno != EBUSY)
        fail("can't mount %s on %s: %s", type, dir, strerror(errno));
}

static void open_consoles(void)
{
    char active[256], path[64], *name, *save = NULL;

    if (read_file("/sys/class/tty/console/active", active, sizeof active) < 0)
        return;
    for (name = strtok_r(active, " ", &save); name && nconsoles < MAX_CONSOLES;
         name = strtok_r(NULL, " ", &save)) {
        int fd;
        snprintf(path, sizeof path, "/dev/%s", name);
        fd = open(path, O_RDWR | O_NOCTTY | O_CLOEXEC);
        if (fd >= 0)
            consoles[nconsoles++] = fd;
    }
}

static void parse_cmdline(void)
{
    char cmdline[4096], *word, *save = NULL;

    if (read_file("/proc/cmdline", cmdline, sizeof cmdline) < 0)
        return;
    for (word = strtok_r(cmdline, " ", &save); word; word = strtok_r(NULL, " ", &save)) {
        if (strncmp(word, "root=PARTLABEL=", 15) == 0)
            snprintf(root_label, sizeof root_label, "%s", word + 15);
        else if (strncmp(word, "root=/dev/", 10) == 0)
            snprintf(root_dev, sizeof root_dev, "%s", word + 5);
        else if (strncmp(word, "root=", 5) == 0)
            say("ignoring %s: use root=/dev/NAME or root=PARTLABEL=NAME", word);
        else if (strncmp(word, "rootfstype=", 11) == 0)
            snprintf(root_fstype, sizeof root_fstype, "%s", word + 11);
        else if (strcmp(word, "rw") == 0)
            root_rw = 1;
        else if (strcmp(word, "ro") == 0)
            root_rw = 0;
        else if (strncmp(word, "init=", 5) == 0)
            snprintf(init_path, sizeof init_path, "%s", word + 5);
    }
}

/* A partition the kernel found, e.g. "sdb2". */
struct part {
    char name[256];
};

/* Fill found[] with every partition named root_label; return how many.
 * The kernel lists each disk and partition in /sys/class/block, and for
 * GPT partitions its uevent file has a PARTNAME= line with the name. */
static int find_partitions(struct part *found)
{
    DIR *dir = opendir("/sys/class/block");
    struct dirent *e;
    char path[512], uevent[1024], want[96];
    int n = 0;

    if (!dir)
        return 0;
    snprintf(want, sizeof want, "\nPARTNAME=%s\n", root_label);
    while ((e = readdir(dir)) && n < MAX_FOUND) {
        if (e->d_name[0] == '.')
            continue;
        snprintf(path, sizeof path, "/sys/class/block/%s/uevent", e->d_name);
        if (read_file(path, uevent + 1, sizeof uevent - 2) < 0)
            continue;
        uevent[0] = '\n';                       /* so every line starts with \n */
        strcat(uevent, "\n");
        if (strstr(uevent, want))
            snprintf(found[n++].name, sizeof found[0].name, "%s", e->d_name);
    }
    closedir(dir);
    return n;
}

/* "sdb2" -> "SanDisk Ultra, 2.0 GB partition on sdb" (as far as we can tell). */
static void describe(const char *name, char *buf, size_t size)
{
    char path[600], link[512], disk[256] = "?", model[128] = "", sectors[32] = "0";
    ssize_t len;
    char *slash;

    /* /sys/class/block/sdb2 links to .../block/sdb/sdb2: the parent is the disk. */
    snprintf(path, sizeof path, "/sys/class/block/%s", name);
    len = readlink(path, link, sizeof link - 1);
    if (len > 0) {
        link[len] = '\0';
        if ((slash = strrchr(link, '/'))) {
            *slash = '\0';
            if ((slash = strrchr(link, '/')))
                snprintf(disk, sizeof disk, "%s", slash + 1);
        }
    }
    snprintf(path, sizeof path, "/sys/class/block/%s/device/model", disk);
    read_file(path, model, sizeof model);
    snprintf(path, sizeof path, "/sys/class/block/%s/size", name);
    read_file(path, sectors, sizeof sectors);
    snprintf(buf, size, "/dev/%s: %.1f GB partition on %s%s%s%s", name,
             strtoull(sectors, NULL, 10) * 512.0 / 1e9, disk,
             model[0] ? " (" : "", model, model[0] ? ")" : "");
}

/* More than one LakerLinux disk: ask on every console which to start.
 * Returns an index into found[]; the first if nobody answers in time. */
static int choose(struct part *found, int n)
{
    struct pollfd fds[MAX_CONSOLES];
    char line[1024];
    int i, waited;

    say("Found %d LakerLinux systems:", n);
    for (i = 0; i < n; i++) {
        describe(found[i].name, line, sizeof line);
        say("  %d) %s", i + 1, line);
    }
    say("Which one should start? Type its number and press Enter "
        "(1 in %d seconds).", CHOOSE_SECONDS);
    for (i = 0; i < nconsoles; i++) {
        fds[i].fd = consoles[i];
        fds[i].events = POLLIN;
    }
    for (waited = 0; waited < CHOOSE_SECONDS * 10; waited++) {
        if (poll(fds, nconsoles, 100) <= 0)
            continue;
        for (i = 0; i < nconsoles; i++) {
            ssize_t len;
            int pick;
            if (!(fds[i].revents & POLLIN))
                continue;
            len = read(fds[i].fd, line, sizeof line - 1);
            if (len <= 0)
                continue;
            line[len] = '\0';
            pick = atoi(line);
            if (pick >= 1 && pick <= n)
                return pick - 1;
            say("Please type a number from 1 to %d.", n);
        }
    }
    return 0;
}

/* Wait for the root partition to appear; return its device, e.g. "/dev/sdb2". */
static void find_root(char *dev, size_t size)
{
    struct part found[MAX_FOUND];
    struct stat st;
    int n, tenths = 0;

    for (;; tenths++) {
        if (root_dev[0]) {
            if (stat(root_dev, &st) == 0) {
                snprintf(dev, size, "%s", root_dev);
                return;
            }
        } else if ((n = find_partitions(found)) > 0) {
            /* Give any other disks a moment to show up too, so we notice if
             * there's a choice to make. */
            sleep_ms(1000);
            n = find_partitions(found);
            snprintf(dev, size, "/dev/%s", found[n > 1 ? choose(found, n) : 0].name);
            return;
        }
        if (tenths == 50 || (tenths > 50 && tenths % 300 == 0)) {
            if (root_dev[0])
                say("waiting for %s to appear...", root_dev);
            else
                say("waiting for a partition named \"%s\" to appear "
                    "(is the LakerLinux disk plugged in?)...", root_label);
        }
        sleep_ms(100);
    }
}

/* Mount dev on NEWROOT. With rootfstype= use that file system type, else try
 * each type the kernel supports, like the kernel itself does. */
static void mount_root(const char *dev)
{
    unsigned long flags = root_rw ? 0 : MS_RDONLY;
    char types[2048], *line, *save = NULL;

    mkdir(NEWROOT, 0755);
    if (root_fstype[0]) {
        if (mount(dev, NEWROOT, root_fstype, flags, NULL) == 0)
            return;
        fail("can't mount %s as %s: %s", dev, root_fstype, strerror(errno));
    }
    /* /proc/filesystems lines are "nodev\tproc" or "\text4"; only the second
     * kind live on disks. */
    if (read_file("/proc/filesystems", types, sizeof types) == 0) {
        for (line = strtok_r(types, "\n", &save); line; line = strtok_r(NULL, "\n", &save)) {
            if (strncmp(line, "nodev", 5) == 0)
                continue;
            while (*line == '\t' || *line == ' ')
                line++;
            if (mount(dev, NEWROOT, line, flags, NULL) == 0)
                return;
        }
    }
    fail("can't mount %s: no file system the kernel knows about", dev);
}

int main(int argc, char **argv)
{
    char dev[300], path[300];
    struct stat st;

    (void)argc;
    mount_or_fail("devtmpfs", "/dev", "devtmpfs");
    mount_or_fail("proc", "/proc", "proc");
    mount_or_fail("sysfs", "/sys", "sysfs");
    open_consoles();
    parse_cmdline();

    find_root(dev, sizeof dev);
    say("starting LakerLinux from %s", dev);
    mount_root(dev);
    /* lstat: /sbin/init is often a symlink, which may only make sense once
     * NEWROOT is the root directory. */
    snprintf(path, sizeof path, NEWROOT "%s", init_path);
    if (lstat(path, &st) < 0)
        fail("%s has no %s", dev, init_path);

    /* Hand over. The real system mounts its own /proc and /sys, but /dev
     * moves across: the devices are already there, and its boot scripts
     * expect them. */
    umount("/proc");
    umount("/sys");
    mkdir(NEWROOT "/dev", 0755);
    if (mount("/dev", NEWROOT "/dev", NULL, MS_MOVE, NULL) < 0)
        umount("/dev");
    unlink("/init");    /* frees its memory: the initramfs lives in RAM */

    /* Make NEWROOT the root directory (what the switch_root command does). */
    if (chdir(NEWROOT) < 0 || mount(".", "/", NULL, MS_MOVE, NULL) < 0 ||
        chroot(".") < 0 || chdir("/") < 0)
        fail("can't switch to the new root: %s", strerror(errno));

    /* The real init takes over as process 1, with any arguments the kernel
     * gave us (e.g. a runlevel). */
    argv[0] = init_path;
    execv(init_path, argv);
    fail("can't run %s: %s", init_path, strerror(errno));
    return 1;
}
