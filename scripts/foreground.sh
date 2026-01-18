#!/bin/bash
# Apache foreground runner for Docker/Supervisor

# Get process group for signal handling
read pid cmd state ppid pgrp session tty_nr tpgid rest < /proc/self/stat
trap "kill -TERM -$pgrp; exit" EXIT TERM KILL SIGKILL SIGTERM SIGQUIT

# Source Apache environment variables
source /etc/apache2/envvars

# Remove any stale PID file
rm -f /var/run/apache2/apache2.pid

# Start Apache in foreground mode
exec apache2 -D FOREGROUND
