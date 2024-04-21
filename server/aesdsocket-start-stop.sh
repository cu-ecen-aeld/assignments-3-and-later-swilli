#! /bin/sh

case "$1" in
  start)
    echo "Starting aesdsocket"
    start-stop-daemon -S aesdsocket -- -d
    ;;
  stop)
    echo "Stopping aesdsocket"
    start-stop-daemon -K aesdsocket
    ;;
  *)
    echo "Usage: aesdsocket-start-stop.sh {start|stop}"
    exit 1
    ;;
esac

exit 0