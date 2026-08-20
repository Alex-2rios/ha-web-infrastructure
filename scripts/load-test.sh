#!/usr/bin/env bash
set -uo pipefail

BASE_URL="${BASE_URL:-https://localhost:8443}"
REQUESTS="${REQUESTS:-200}"
CONCURRENCY="${CONCURRENCY:-25}"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "firing $REQUESTS requests at $BASE_URL, $CONCURRENCY at a time"
echo

started="$(date +%s)"

burst() {
    curl -sk -o /dev/null -w "%{http_code} %{time_total}\n" --max-time 5 "$BASE_URL/api/whoami"
}

mkdir -p "$TMP/parts"

sent=0
while [ "$sent" -lt "$REQUESTS" ]; do
    batch="$CONCURRENCY"
    if [ $((sent + batch)) -gt "$REQUESTS" ]; then
        batch=$((REQUESTS - sent))
    fi

    for slot in $(seq 1 "$batch"); do
        burst > "$TMP/parts/$((sent + slot))" &
    done
    wait

    sent=$((sent + batch))
done

cat "$TMP"/parts/* > "$TMP/results"

elapsed=$(( $(date +%s) - started ))
[ "$elapsed" -eq 0 ] && elapsed=1

echo "status codes"
awk '{print $1}' "$TMP/results" | sort | uniq -c | sort -rn | while read -r count code; do
    case "$code" in
        200) label="served" ;;
        429) label="rate limited by nginx" ;;
        502|503|504) label="backend unavailable" ;;
        000) label="no response" ;;
        *)   label="" ;;
    esac
    printf '  %-6s %-6s %s\n' "$code" "$count" "$label"
done

echo
awk '{ total += $2; if ($2 > max) max = $2 } END {
    printf "  requests   %d\n", NR
    printf "  mean       %.0f ms\n", (total / NR) * 1000
    printf "  slowest    %.0f ms\n", max * 1000
}' "$TMP/results"

printf '  duration   %ss, about %s requests per second\n' "$elapsed" "$((REQUESTS / elapsed))"

echo
echo "a 429 here is the rate limiter working, not a failure."
echo "raise CONCURRENCY until you see them, then look at limit_req in nginx/conf.d/default.conf"
