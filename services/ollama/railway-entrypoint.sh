#!/bin/bash
# Starts "ollama serve", then pulls every model listed in OLLAMA_PULL_MODELS that is not
# already on the volume. The server keeps running if a pull fails.
set -uo pipefail

/bin/ollama serve &
SERVER_PID=$!
trap 'kill -TERM "$SERVER_PID" 2>/dev/null; wait "$SERVER_PID"; exit $?' TERM INT

client() { OLLAMA_HOST=127.0.0.1:11434 /bin/ollama "$@"; }

for _ in $(seq 1 120); do
  client list >/dev/null 2>&1 && break
  sleep 1
done

MODELS="${OLLAMA_PULL_MODELS:-}"
for model in ${MODELS//,/ }; do
  if client show "$model" >/dev/null 2>&1; then
    echo "[railway] model $model already present"
  else
    echo "[railway] pulling $model (first boot only)"
    client pull "$model" || echo "[railway] WARNING: pull of $model failed; retry with 'ollama pull $model'"
  fi
done

wait "$SERVER_PID"
