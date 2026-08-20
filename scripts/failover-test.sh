#!/usr/bin/env bash
set -uo pipefail

BASE_URL="${BASE_URL:-https://localhost:8443}"
SAMPLES="${SAMPLES:-20}"
LOG="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/docs/last-run.log"

: > "$LOG"

say() { printf '%s\n' "$*" | tee -a "$LOG"; }

hit() {
    curl -sk --max-time 3 "$BASE_URL/api/whoami" \
        | sed -n 's/.*"node":[[:space:]]*"\([^"]*\)".*/\1/p'
}

health() {
    docker exec "ha-$1" python -c \
        "import urllib.request as u; u.urlopen(u.Request('http://127.0.0.1:5000/admin/health/$2', method='POST'))" \
        >/dev/null 2>&1
}

distribution() {
    local label="$1" w1=0 w2=0 err=0 node
    for _ in $(seq 1 "$SAMPLES"); do
        node="$(hit)"
        case "$node" in
            web1) w1=$((w1 + 1)) ;;
            web2) w2=$((w2 + 1)) ;;
            *)    err=$((err + 1)) ;;
        esac
    done
    printf '%-24s web1=%-4s web2=%-4s failed=%s\n' "$label" "$w1" "$w2" "$err" | tee -a "$LOG"
}

sustained() {
    local label="$1" seconds="$2" ok=0 bad=0 deadline
    deadline=$(( $(date +%s) + seconds ))
    while [ "$(date +%s)" -lt "$deadline" ]; do
        if [ -n "$(hit)" ]; then ok=$((ok + 1)); else bad=$((bad + 1)); fi
    done
    printf '%-24s ok=%-6s failed=%s\n' "$label" "$ok" "$bad" | tee -a "$LOG"
}

say "target      : $BASE_URL"
say "samples/run : $SAMPLES"
say "started     : $(date '+%F %T')"
say ""

say "[1] baseline, both backends healthy"
distribution "round robin"
say ""

say "[2] graceful drain of web1 (health endpoint returns 503)"
health web1 down
sleep 6
distribution "web1 draining"
say ""

say "[3] web1 back in the pool"
health web1 up
sleep 6
distribution "recovered"
say ""

say "[4] hard failure: stopping the web2 container mid-traffic"
( sleep 3; docker stop ha-web2 >/dev/null 2>&1 ) &
sustained "traffic during kill" 12
docker start ha-web2 >/dev/null 2>&1
sleep 8
say ""

say "[5] steady state after restart"
distribution "final"
say ""
say "finished    : $(date '+%F %T')"
say "log         : $LOG"
