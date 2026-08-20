#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ ! -f "$ROOT/certs/server.crt" ]; then
    echo "no certificate found, generating a self-signed one"
    "$ROOT/certs/generate-certs.sh" localhost
fi

docker compose -f "$ROOT/docker-compose.yml" up -d --build

echo
echo "waiting for the edge to answer"
for _ in $(seq 1 60); do
    if curl -sk --max-time 2 https://localhost:8443/nginx-health >/dev/null; then
        echo "stack is up"
        echo "  site    https://localhost:8443"
        echo "  stats   http://localhost:8404"
        exit 0
    fi
    sleep 1
done

echo "the edge never became ready, here is what it said:" >&2
docker compose -f "$ROOT/docker-compose.yml" logs --tail 30 edge >&2
exit 1
