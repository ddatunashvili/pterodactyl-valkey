#!/bin/bash
cd /home/container || exit 1

# All data (AOF, RDB snapshots) lives in the server volume.
mkdir -p /home/container/data

if [ -z "${VALKEY_PASSWORD:-}" ]; then
    echo "Renode: VALKEY_PASSWORD is empty. Refusing to start an open Valkey on a public port."
    exit 1
fi

PORT="${SERVER_PORT:-6379}"
POLICY="${VALKEY_MAXMEMORY_POLICY:-noeviction}"

# maxmemory at ~80% of the container limit, leaving room for the process
# itself, AOF rewrites and fork copy-on-write. A server past its limit is
# OOM-killed; one at maxmemory refuses writes (noeviction) or evicts.
LIMIT=""
if [ -r /sys/fs/cgroup/memory.max ]; then
    LIMIT=$(cat /sys/fs/cgroup/memory.max)
elif [ -r /sys/fs/cgroup/memory/memory.limit_in_bytes ]; then
    LIMIT=$(cat /sys/fs/cgroup/memory/memory.limit_in_bytes)
fi
if [[ "$LIMIT" =~ ^[0-9]+$ ]] && [ "$LIMIT" -lt 1099511627776 ]; then
    MAXMEMORY=$(( LIMIT * 8 / 10 ))
else
    MAXMEMORY=$(( 256 * 1024 * 1024 ))
fi

# The config carries the password, so it is written outside the volume (the
# customer's file manager) and readable by this user only.
CONF=/tmp/valkey.conf
umask 077
cat > "$CONF" <<CONF
port ${PORT}
bind 0.0.0.0 -::*
protected-mode yes
requirepass "${VALKEY_PASSWORD}"
dir /home/container/data
appendonly yes
appendfsync everysec
save 3600 1 300 100 60 10000
maxmemory ${MAXMEMORY}
maxmemory-policy ${POLICY}
enable-debug-command no
enable-module-command no
daemonize no
logfile ""
CONF
umask 022

export VALKEY_CONF="$CONF"
export REDISCLI_AUTH="${VALKEY_PASSWORD}"

# Pterodactyl startup: {{VAR}} -> ${VAR}. Run as a script, not through
# `eval echo`: the panel may prefix it with commands of its own (a console
# banner), and `eval echo` would run those inside a command substitution.
MODIFIED_STARTUP=$(printf '%s' "${STARTUP:-valkey-server /tmp/valkey.conf}" | sed -e 's/{{/${/g' -e 's/}}/}/g')
echo ":/home/container$ ${MODIFIED_STARTUP}"

# Own session, so shutdown can signal the whole tree at once.
setsid bash -c "${MODIFIED_STARTUP}" </dev/null &
PID=$!

shutdown() {
    echo "Stopping Valkey..."
    kill -TERM -- "-$PID" 2>/dev/null || kill -TERM "$PID" 2>/dev/null
    wait "$PID"
    exit $?
}
trap shutdown INT TERM

# Panel console lines run as Valkey commands. REDISCLI_AUTH keeps the password
# off the command line. In the background, so the container lives exactly as
# long as Valkey does; stdin is passed explicitly.
exec 3<&0
while IFS= read -r line <&3; do
    [ -z "$line" ] && continue
    # shellcheck disable=SC2086
    valkey-cli -p "$PORT" --no-auth-warning $line || true
done &

wait "$PID"
exit $?
