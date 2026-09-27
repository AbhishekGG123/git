#!/bin/bash

set -e

mkdir -p /app/workspace

echo "Starting DeepSeek Harness..."

cd /app/workspace

dsh web --no-open --port 3080 &
HARNESS_PID=$!

echo "Starting Caddy..."

caddy run --config /etc/caddy/Caddyfile &
CADDY_PID=$!

trap 'kill $HARNESS_PID $CADDY_PID 2>/dev/null || true' SIGTERM SIGINT

wait -n $HARNESS_PID $CADDY_PID
