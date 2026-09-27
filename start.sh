#!/bin/sh
set -eu

: "${PUBLIC_HOST:?Set PUBLIC_HOST to your Northflank public hostname}"
: "${HARNESS_USER:?Set HARNESS_USER}"
: "${HARNESS_PASSWORD:?Set HARNESS_PASSWORD}"

# Create the reverse-proxy login used to protect the public Harness UI.
htpasswd -bc /etc/nginx/.htpasswd "$HARNESS_USER" "$HARNESS_PASSWORD" >/dev/null

echo "=================================================="
echo "DeepSeek Harness"
echo "PUBLIC_HOST: ${PUBLIC_HOST}"
echo "Harness:     127.0.0.1:3080"
echo "Proxy:       0.0.0.0:8080"
echo "=================================================="

# Keep Harness bound to loopback. The remote browser reaches it through nginx.
pnpm dsh web \
  --host 127.0.0.1 \
  --no-open \
  --port 3080 \
  --trusted-host "${PUBLIC_HOST}" &
HARNESS_PID=$!

nginx -g 'daemon off;' &
NGINX_PID=$!

cleanup() {
  kill "$HARNESS_PID" "$NGINX_PID" 2>/dev/null || true
}
trap cleanup INT TERM EXIT

wait -n "$HARNESS_PID" "$NGINX_PID"
exit $?
