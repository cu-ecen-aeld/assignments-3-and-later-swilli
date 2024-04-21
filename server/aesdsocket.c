#include <sys/socket.h>
#include <syslog.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <stdlib.h>
#include <errno.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <signal.h>
#include <stdio.h>

static const char data_file_path[] = "/var/tmp/aesdsocketdata";
static const short port_number = 9000;
static const size_t buf_size = 64;

static char do_run = 1;

static void signal_handler(int signo) {
    do_run = 0;   
}

static void syslog_then_exit(const char* const reason) {
    const int enr = errno;
    syslog(LOG_ERR, "aesdsocket aborting. function=%s errno=%s", reason, strerror(enr));
    exit(-1);
    
}

int main(int argc, char* argv[]) {
    openlog(NULL, 0, LOG_USER);

    struct sigaction action = {};
    action.sa_handler = &signal_handler;

    if (sigaction(SIGINT, &action, NULL) != 0) {
        syslog_then_exit("sigaction");
    }
    if (sigaction(SIGTERM, &action, NULL) != 0) {
        syslog_then_exit("sigaction");
    }

    const int sock_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (sock_fd < 0) {
        syslog_then_exit("socket");
    }

    const int enable = 1;
    if (setsockopt(sock_fd, SOL_SOCKET, SO_REUSEADDR, &enable, sizeof(enable)) < 0) {
        syslog_then_exit("setsockopt");
    }
    
    struct sockaddr_in local;
    local.sin_family = AF_INET;
    local.sin_port = htons(port_number);
    inet_aton("0.0.0.0", (struct in_addr*) &local.sin_addr.s_addr);
    
    if (bind(sock_fd, (struct sockaddr*) &local, sizeof(local)) < 0) {
        syslog_then_exit("bind");
    }

    if ((argc > 1) && (strcmp(argv[1],"-d") == 0)) {
        const pid_t pid = fork();
        if (pid == 0) {
            if (!((setsid() > 0) && !close(STDIN_FILENO) && !close(STDOUT_FILENO) && !close(STDERR_FILENO))) {
                syslog_then_exit("fork");
            }
        } else {
            exit(EXIT_SUCCESS);
        }
    }

    if (listen(sock_fd, 1) < 0) {
        syslog_then_exit("listen");
    }

    struct sockaddr_in remote = {};
    socklen_t len = sizeof(remote);

    while (do_run) {
        const int client_fd = accept(sock_fd, (struct sockaddr*) &remote, &len);
        if (client_fd < 0) {
            if (!do_run) {
                break;
            } 
            syslog_then_exit("accept");
        }

        char str[INET_ADDRSTRLEN];
        inet_ntop(AF_INET, &remote.sin_addr, str, INET_ADDRSTRLEN);
        syslog(LOG_INFO, "Accepted connection from %s", str);

        const int file_fd = open(data_file_path, O_CREAT | O_RDWR | O_APPEND, 0644);
        if (file_fd < 0) {
            syslog_then_exit("open");
        }

        while (1) {
            char buf[buf_size]; 

            const ssize_t recv_len = recv(client_fd, buf, sizeof(buf), 0);
            if (recv_len <= 0) {
                close(client_fd);
                break;
            }

            size_t write_len = 0;
            char found = 0;
            for (; write_len < recv_len; write_len++) {
                if (buf[write_len] == '\n') {
                    write_len += 1;
                    found = 1;
                    break;
                }
            }

            if (write(file_fd, buf, write_len) < 0) {
                syslog_then_exit("write");
            }

            if (found) {
                const int data_fd = open(data_file_path, O_RDONLY, 0);
                if (data_fd < 0) {
                    syslog_then_exit("open_read");
                }
                while (1) {
                    const ssize_t read_len = read(data_fd, buf, sizeof(buf));
                    if (read_len < 0) {
                        syslog_then_exit("read");
                    }
                    if (read_len == 0) {
                        break;
                    }

                    const ssize_t send_len = send(client_fd, buf, read_len, 0);
                    if (send_len != read_len) {
                        syslog_then_exit("send");
                    }
                }
                close(data_fd);
            }
        }
        
        syslog(LOG_INFO, "Closed connection from %s", str);
    }
    
    close(sock_fd);

    unlink(data_file_path);

    syslog(LOG_INFO, "Caught signal, exiting");

    return 0;
}