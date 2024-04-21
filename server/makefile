ifdef CROSS_COMPILE
	CC=$(CROSS_COMPILE)gcc
endif

CFLAGS += -Wall -Werror

all:
	$(CC) -o aesdsocket aesdsocket.c

clean:
	rm -f aesdsocket
