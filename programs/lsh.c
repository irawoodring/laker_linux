/* lsh.c: the simplest shell. Read a command, run it, repeat. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/wait.h>

int main(void)
{
    char line[1024];
    char *argv[64];

    for (;;) {
        printf("lsh$ ");
        fflush(stdout);
        if (!fgets(line, sizeof line, stdin))   /* Ctrl-D: end of input */
            break;

        /* Split the line into words: "ls -l /tmp" -> {"ls", "-l", "/tmp", NULL} */
        int argc = 0;
        for (char *w = strtok(line, " \t\n"); w && argc < 63; w = strtok(NULL, " \t\n"))
            argv[argc++] = w;
        argv[argc] = NULL;
        if (argc == 0)
            continue;

        /* Built-ins: these must run inside the shell itself (see below). */
        if (strcmp(argv[0], "exit") == 0)
            break;
        if (strcmp(argv[0], "cd") == 0) {
            if (chdir(argc > 1 ? argv[1] : getenv("HOME")) < 0)
                perror("cd");
            continue;
        }

        /* Everything else: a new process that becomes the program. */
        pid_t pid = fork();
        if (pid == 0) {
            execvp(argv[0], argv);              /* only returns if it failed */
            perror(argv[0]);
            exit(127);
        }
        int status;
        waitpid(pid, &status, 0);               /* wait for it to finish */
    }
    return 0;
}
