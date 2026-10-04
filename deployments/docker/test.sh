#!/usr/bin/env bash
set -euo pipefail

# Build images and start stack
compose_dir="$(cd "$(dirname "$0")" && pwd)"
cd "$compose_dir"

echo "[+] Building and starting docker-compose stack"
docker compose up -d --build

# Wait for app HTTP health (distroless image has no container healthcheck)
echo "[+] Waiting for app HTTP health at http://localhost:8080/actuator/health"
for i in {1..60}; do
  if curl -fsS http://localhost:8080/actuator/health >/dev/null 2>&1; then
    echo "[+] App is healthy"; break
  fi
  sleep 5
  if [[ $i -eq 60 ]]; then echo "[-] App failed to become healthy"; docker compose logs app; exit 1; fi
done

# Hit health endpoint
curl -fsS http://localhost:8080/actuator/health | jq .

# API endpoints require authentication; anonymous requests must be rejected.
set +e
http_code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/api/v1/contacts/00000000-0000-0000-0000-000000000000)
set -e
if [[ "$http_code" != "401" && "$http_code" != "403" ]]; then
  echo "[-] Unexpected status code from GET contact: $http_code"; docker compose logs app; exit 1
fi

echo "[+] E2E smoke succeeded"
