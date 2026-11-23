#!/bin/bash
set -eu
DIR=/home/repo/bootdo/target
LIVE="$DIR/bootdo-1.7.0.jar"
CAND="$LIVE.petmemorial-candidate"
STAMP=$(date +%Y%m%d-%H%M%S)
BACKUP="$LIVE.pre-petmemorial-$STAMP"
LOG="$DIR/bootdo-console.log"
test -s "$CAND"
OLDPID=$(cat "$DIR/bootdo.pid")
kill -0 "$OLDPID"
tr '\0' ' ' < "/proc/$OLDPID/cmdline" | grep -F "$LIVE" >/dev/null
cp -p "$LIVE" "$BACKUP"
printf '%s\n' "$BACKUP" > "$DIR/petmemorial-rollback-path"
kill -TERM "$OLDPID"
for i in $(seq 1 40); do kill -0 "$OLDPID" 2>/dev/null || break; sleep 1; done
if kill -0 "$OLDPID" 2>/dev/null; then echo 'ABORT: original process did not stop; live jar unchanged'; exit 1; fi
mv "$CAND" "$LIVE"
cd "$DIR"
start() {
    nohup java -Xms128m -Xmx700m -XX:MetaspaceSize=128m -XX:MaxMetaspaceSize=200m -XX:+UseSerialGC -Djava.security.egd=file:/dev/./urandom -jar "$LIVE" --spring.profiles.active=pro >> "$LOG" 2>&1 < /dev/null &
    NEWPID=$!
    echo "$NEWPID" > "$DIR/bootdo.pid"
}
start
READY=0
for i in $(seq 1 90); do
    kill -0 "$NEWPID" 2>/dev/null || break
    if curl -kfsS --max-time 3 https://127.0.0.1:8066/api/petmemorial/health 2>/dev/null | grep -q '"ok"'; then
        if curl -kfsS --max-time 3 https://127.0.0.1:8066/im/bot/navi/vip/products 2>/dev/null | grep -Eq '"code"[[:space:]]*:[[:space:]]*0'; then READY=1; break; fi
    fi
    sleep 1
 done
if [ "$READY" -ne 1 ]; then
    kill -TERM "$NEWPID" 2>/dev/null || true
    for i in $(seq 1 30); do kill -0 "$NEWPID" 2>/dev/null || break; sleep 1; done
    if kill -0 "$NEWPID" 2>/dev/null; then echo 'ROLLBACK WAIT: new process still running; manual stop required'; exit 2; fi
    mv "$LIVE" "$LIVE.failed-$STAMP"
    cp -p "$BACKUP" "$LIVE"
    start
    echo "ROLLED_BACK $BACKUP pid=$NEWPID"
    exit 1
fi
echo "DEPLOYED backup=$BACKUP pid=$NEWPID"
free -m
