#!/bin/sh
# Seeds a fresh n8n database. Safe to re-run: does nothing once any workflow exists.
set -eu

: "${N8N_MAIN_READY_URL:?N8N_MAIN_READY_URL is required}"
: "${OLLAMA_BASE_URL:?OLLAMA_BASE_URL is required}"
: "${QDRANT_URL:?QDRANT_URL is required}"
: "${QDRANT_API_KEY:?QDRANT_API_KEY is required}"
MODEL="${DEMO_CHAT_MODEL:-llama3.2:3b}"

echo "[bootstrap] waiting for n8n main (migrations) at $N8N_MAIN_READY_URL"
tries=0
until wget -q -O /dev/null "$N8N_MAIN_READY_URL"; do
  tries=$((tries + 1))
  if [ "$tries" -gt 120 ]; then
    echo "[bootstrap] n8n main not ready after 10 minutes" >&2
    exit 1
  fi
  sleep 5
done

# Workflow IDs are 16-character nanoids; ignore any log lines the CLI prints.
if n8n list:workflow --onlyId 2>/dev/null | grep -Eq '^[A-Za-z0-9]{16}$'; then
  echo "[bootstrap] workflows already exist, nothing to do"
  exit 0
fi

SEED=$(mktemp -d)
mkdir -p "$SEED/credentials" "$SEED/workflows"

# Plain credential data; n8n encrypts it with N8N_ENCRYPTION_KEY during import.
cat > "$SEED/credentials/ollama.json" <<JSON
{"id":"railwayOllama001","name":"Ollama (Railway)","type":"ollamaApi","data":{"baseUrl":"${OLLAMA_BASE_URL}"}}
JSON
cat > "$SEED/credentials/qdrant.json" <<JSON
{"id":"railwayQdrant001","name":"Qdrant (Railway)","type":"qdrantApi","data":{"qdrantUrl":"${QDRANT_URL}","apiKey":"${QDRANT_API_KEY}"}}
JSON
sed "s|__CHAT_MODEL__|${MODEL}|g" /home/node/demo-workflow.json.tmpl > "$SEED/workflows/demo.json"

n8n import:credentials --separate --input="$SEED/credentials"
n8n import:workflow --separate --input="$SEED/workflows"
rm -rf "$SEED"
echo "[bootstrap] imported Ollama + Qdrant credentials and the demo workflow"
