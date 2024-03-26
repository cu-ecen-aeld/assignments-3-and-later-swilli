#include <syslog.h>
#include <fcntl.h>
#include <string.h>
#include <errno.h>
#include <unistd.h>

int main(int argc, char *argv[]) {
    openlog(0x00, 0, LOG_USER);

    if (argc < 3) {
        syslog(LOG_ERR, "Invalid number of arguments (%d)", argc - 1);
        return 1;
    }

    const char* writefile = argv[1];
    const char* writestr = argv[2];

    syslog(LOG_DEBUG, "Writing %s to %s", writestr, writefile);
    
    const int handle = open(writefile, O_CREAT | O_RDWR, 0644);
    if (handle < 0) {
        const int err = errno;
        syslog(LOG_ERR, "open failed (%s)", strerror(err));
        return 1;
    }
    if (write(handle, writestr, strlen(writestr)) == -1) {
        const int err = errno;
        syslog(LOG_ERR, "write failed (%s)", strerror(err));
        return 1;
    }
    if (close(handle) < 0) {
        const int err = errno;
        syslog(LOG_ERR, "close failed (%s)", strerror(err));
        return 1;
    }

    return 0;
}