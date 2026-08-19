#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CN="${1:-localhost}"

SAN="DNS:$CN,IP:127.0.0.1"
[ "$CN" = "localhost" ] || SAN="DNS:$CN,DNS:localhost,IP:127.0.0.1"

case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*) export MSYS2_ARG_CONV_EXCL='/C=' ;;
esac

openssl req -x509 -nodes -newkey rsa:2048 \
    -days 365 \
    -keyout "$DIR/server.key" \
    -out "$DIR/server.crt" \
    -subj "/C=MX/ST=Coahuila/L=Saltillo/O=Homelab/CN=$CN" \
    -addext "subjectAltName=$SAN"

chmod 600 "$DIR/server.key"
openssl x509 -in "$DIR/server.crt" -noout -subject -dates
