# n8n 2 AI Agent Stack (Ollama + Qdrant) — Railway template spec

## Listing

| Field | Value |
|---|---|
| Name | **n8n 2 AI Agent Stack (Ollama + Qdrant)** (version label `2` = n8n major version; n8n tags `n8n@2.x.y` and markets "n8n 2.0") |
| Description | n8n queue mode with workers, local LLMs via Ollama and Qdrant memory. (76 chars) |
| Category | Automation |
| Tags | n8n, automation, ai-agents, ollama, qdrant, queue, workers, llm |
| User input at deploy | **None.** Owner account is created in the browser on first visit (n8n's own setup flow). |

## Base market template

- **`n8n-with-workers` "N8N (w/ workers)"** (114,186 projects, 81,066 active — the marketplace leader) — chosen as base. Kept: queue mode, primary + worker split, `EXECUTIONS_MODE=queue`, `OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS=true`, `QUEUE_BULL_REDIS_DUALSTACK=true`, `N8N_LISTEN_ADDRESS=::`, encryption key shared by reference. Fixed: unpinned `n8nio/n8n` (latest), `railwayapp/redis` (Bitnami-based) and Postgres 17 with public TCP proxies, `DATABASE_URL` typo (`${{{PSTGRES_DB}}`), `N8N_TRUST_PROXY` (not an n8n variable), no task runners, filesystem binary data default, no AI services.
- `Xx4_lu` "flowise-with-n8n-ai-automation" — n8n built from `_upstream/derekcheungsa__n8n-railway-custom` (**no license**, `latest`, build-time DB credentials, legacy basic auth). Reference only; nothing reused.
- `9router-ai-gateway` — unrelated AI gateway; nothing reused.
- **Upstream AI kit:** [`n8n-io/self-hosted-ai-starter-kit`](https://github.com/n8n-io/self-hosted-ai-starter-kit) (Apache-2.0, commit `662bd88`): n8n + Postgres + Qdrant + Ollama + `ollama pull` init + `n8n-import` demo seed. Service set and the seed idea adapted (see NOTICE.md).

## Pinned versions

| Service | Image / source | Tag | Release date | Checked |
|---|---|---|---|---|
| n8n Main / Webhook / Worker | `n8nio/n8n` | `2.42.6` | 2026-10-09 (current `stable`) | 2026-10-11 |
| n8n Task Runners | `n8nio/runners` | `2.42.6` | 2026-10-09 | 2026-10-11 |
| n8n Bootstrap | `n8nio/n8n` (wrapped: `services/bootstrap`) | `2.42.6` | 2026-10-09 | 2026-10-11 |
| Ollama | `ollama/ollama` (wrapped: `services/ollama`) | `0.40.3` | 2026-10-11 | 2026-10-11 |
| Qdrant | `qdrant/qdrant` | `v1.19.2` | 2026-10-05 | 2026-10-11 |
| Gateway | `nginx` (wrapped: `services/gateway`) | `1.30.5-alpine` | image build 2026-09-26 | 2026-10-11 |
| Postgres | `ghcr.io/railwayapp-templates/postgres-ssl` | `18` | Railway base | 2026-10-11 |
| Redis | `redis` | `8.2` | Railway base | 2026-10-11 |
| Models (pulled at runtime) | `llama3.2:3b`, `nomic-embed-text:v1.5` | — | Ollama library | 2026-10-11 |

- n8n `2.43.x` is the `beta` channel; `2.42.6` is the newest release on the `stable` channel. Upgrade path: set the same new tag on n8n Main, n8n Webhook, n8n Worker, n8n Task Runners and the Bootstrap `FROM` line (runners must match the n8n version), back up Postgres, redeploy.

## Architecture

```
Internet ─HTTPS─▶ Gateway (nginx, only public domain)
                   ├─ /webhook/ /webhook-waiting/ /form/ /form-waiting/ /mcp/ ─▶ n8n Webhook :5678
                   └─ everything else (editor, /rest, push, *-test endpoints) ───▶ n8n Main :5678
n8n Main + n8n Webhook ──enqueue──▶ Redis (BullMQ) ◀──jobs── n8n Worker (concurrency 10)
n8n Worker :5679 task broker ◀── n8n Task Runners (JS + Python launcher, runs Code nodes)
all n8n processes ─▶ Postgres (workflows, credentials, executions, binary data)
n8n Worker (AI nodes) ─▶ Ollama :11434 (llama3.2:3b, nomic-embed-text) · Qdrant :6333 (vector store)
n8n Bootstrap (one-shot) ─▶ seeds "Ollama (Railway)" + "Qdrant (Railway)" credentials and a demo chat workflow
```

Design decisions (verified in n8n 2.42.6 source/docs):

- **Webhook processor + Gateway**: n8n's queue-mode guide sends `/webhook/*` and `/webhook-waiting/*` to webhook processors and everything else (including `/webhook-test/*`) to main. In 2.42 the webhook process also serves `/form/*`, `/form-waiting/*` and `/mcp/*` (production forms, chat and MCP Server triggers), so those go there too. Main sets `N8N_DISABLE_PRODUCTION_MAIN_PROCESS=true`. A Railway domain targets one service, hence the small nginx Gateway.
- **External task runners**: n8n 2 documents internal mode as "insecure by design" and recommends external mode (`n8nio/runners` sidecar) for production. In queue mode each worker needs its own runner; main needs none because manual executions are offloaded (`OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS=true` makes main skip the runner entirely).
- **Binary data in Postgres** (`N8N_DEFAULT_BINARY_DATA_MODE=database`, also n8n's default in queue mode): filesystem mode is not supported in queue mode and S3 binary storage is a paid n8n feature, so no Bucket is used.
- **No n8n volume**: the encryption key and JWT secret are variables, data and binaries live in Postgres, and community nodes are reinstalled on boot (`N8N_REINSTALL_MISSING_PACKAGES=true`).
- **Ollama on CPU**: Railway has no GPUs. `llama3.2:3b` (same family as the upstream kit, supports tool calling) and `nomic-embed-text` are pulled on first boot by the Ollama wrapper; Ollama has no auth and stays on the private network. Qdrant requires an API key.

## Services

Create in this order. Values are entered exactly as shown (Railway resolves `${{...}}`).

### Gateway

- **Source:** GitHub repo `baranberkay96/n8n-ai-stack-railway`, root directory `/services/gateway` (Dockerfile build)
- **Start command:** image default
- **Healthcheck:** `/gateway-healthz` (timeout 120 s)
- **Public domain:** yes → target port `8080`
- **TCP proxy:** none
- **Volume:** none
- **Restart policy:** ON_FAILURE (max 10 retries)
- **Replicas:** 1

| Variable | Value | Description |
|---|---|---|
| `PORT` | `8080` | Port nginx listens on (public domain target). |
| `N8N_GW_MAIN_UPSTREAM` | `${{n8n Main.RAILWAY_PRIVATE_DOMAIN}}:5678` | n8n main (editor, API, push, test webhooks). |
| `N8N_GW_WEBHOOK_UPSTREAM` | `${{n8n Webhook.RAILWAY_PRIVATE_DOMAIN}}:5678` | Webhook processor (/webhook, /webhook-waiting, /form, /form-waiting, /mcp). |
| `NGINX_CLIENT_MAX_BODY_SIZE` | `200M` | Max request size (form uploads, binary webhooks). |
| `NGINX_PROXY_TIMEOUT` | `3600s` | Proxy timeout for long webhook responses and push connections. |

### n8n Main

- **Source:** Docker image `n8nio/n8n:2.42.6`
- **Start command:** image default
- **Healthcheck:** `/healthz/readiness` (timeout 300 s)
- **Public domain:** no (private network only)
- **TCP proxy:** none
- **Volume:** none
- **Restart policy:** ON_FAILURE (max 10 retries)
- **Replicas:** 1

| Variable | Value | Description |
|---|---|---|
| `PORT` | `5678` | Port Railway health-checks. |
| `N8N_PORT` | `5678` | n8n HTTP port. |
| `N8N_LISTEN_ADDRESS` | `::` | Listen on IPv4+IPv6. |
| `N8N_EDITOR_BASE_URL` | `https://${{Gateway.RAILWAY_PUBLIC_DOMAIN}}` | Public editor URL (links in emails, OAuth callbacks). |
| `OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS` | `true` | Run editor/test executions on workers too (main never runs Code nodes). |
| `N8N_DISABLE_PRODUCTION_MAIN_PROCESS` | `true` | Production webhooks are served by the n8n Webhook service via the Gateway. |
| `N8N_PERSONALIZATION_ENABLED` | `false` | Skip the onboarding survey. |
| `EXECUTIONS_MODE` | `queue` | Queue mode: main/webhook enqueue executions in Redis, workers run them. |
| `DB_TYPE` | `postgresdb` | Database type. |
| `DB_POSTGRESDB_HOST` | `${{Postgres.PGHOST}}` | Postgres private host. |
| `DB_POSTGRESDB_PORT` | `${{Postgres.PGPORT}}` | Postgres port. |
| `DB_POSTGRESDB_DATABASE` | `${{Postgres.PGDATABASE}}` | Postgres database. |
| `DB_POSTGRESDB_USER` | `${{Postgres.PGUSER}}` | Postgres user. |
| `DB_POSTGRESDB_PASSWORD` | `${{Postgres.PGPASSWORD}}` | Postgres password. |
| `QUEUE_BULL_REDIS_HOST` | `${{Redis.REDISHOST}}` | Redis private host. |
| `QUEUE_BULL_REDIS_PORT` | `${{Redis.REDISPORT}}` | Redis port. |
| `QUEUE_BULL_REDIS_USERNAME` | `${{Redis.REDISUSER}}` | Redis user. |
| `QUEUE_BULL_REDIS_PASSWORD` | `${{Redis.REDIS_PASSWORD}}` | Redis password. |
| `QUEUE_BULL_REDIS_DUALSTACK` | `true` | Resolve Redis over IPv4 and IPv6 (Railway private network). |
| `N8N_ENCRYPTION_KEY` | `${{secret(48, "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")}}` | Encrypts stored credentials; identical on every n8n process. Never change after first boot. |
| `N8N_USER_MANAGEMENT_JWT_SECRET` | `${{secret(48, "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")}}` | Signs login sessions; identical on every n8n process. |
| `WEBHOOK_URL` | `https://${{Gateway.RAILWAY_PUBLIC_DOMAIN}}/` | Public base for webhook, form, chat and MCP URLs (the Gateway). |
| `N8N_PROXY_HOPS` | `2` | Trusted proxies in front of n8n (Railway edge + Gateway) for correct client IPs. |
| `N8N_DEFAULT_BINARY_DATA_MODE` | `database` | Binary data in Postgres so main, webhook and workers share files (filesystem mode is unsupported in queue mode). |
| `N8N_REINSTALL_MISSING_PACKAGES` | `true` | Reinstall community nodes on boot (no shared volume between processes). |
| `GENERIC_TIMEZONE` | `Etc/UTC` | Default timezone for schedules (e.g. Europe/Istanbul). |
| `N8N_LOG_LEVEL` | `info` | Log level. |
| `N8N_DIAGNOSTICS_ENABLED` | `false` | Disable anonymous telemetry. |
| `N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS` | `true` | Strict permissions on the n8n settings file. |

### n8n Webhook

- **Source:** Docker image `n8nio/n8n:2.42.6`
- **Start command:** `tini -- /docker-entrypoint.sh webhook`
- **Healthcheck:** `/healthz/readiness` (timeout 300 s)
- **Public domain:** no (private network only)
- **TCP proxy:** none
- **Volume:** none
- **Restart policy:** ON_FAILURE (max 10 retries)
- **Replicas:** 1

| Variable | Value | Description |
|---|---|---|
| `PORT` | `5678` | Port Railway health-checks. |
| `N8N_PORT` | `5678` | n8n HTTP port. |
| `N8N_LISTEN_ADDRESS` | `::` | Listen on IPv4+IPv6. |
| `EXECUTIONS_MODE` | `${{n8n Main.EXECUTIONS_MODE}}` | Queue mode: main/webhook enqueue executions in Redis, workers run them. |
| `DB_TYPE` | `${{n8n Main.DB_TYPE}}` | Database type. |
| `DB_POSTGRESDB_HOST` | `${{n8n Main.DB_POSTGRESDB_HOST}}` | Postgres private host. |
| `DB_POSTGRESDB_PORT` | `${{n8n Main.DB_POSTGRESDB_PORT}}` | Postgres port. |
| `DB_POSTGRESDB_DATABASE` | `${{n8n Main.DB_POSTGRESDB_DATABASE}}` | Postgres database. |
| `DB_POSTGRESDB_USER` | `${{n8n Main.DB_POSTGRESDB_USER}}` | Postgres user. |
| `DB_POSTGRESDB_PASSWORD` | `${{n8n Main.DB_POSTGRESDB_PASSWORD}}` | Postgres password. |
| `QUEUE_BULL_REDIS_HOST` | `${{n8n Main.QUEUE_BULL_REDIS_HOST}}` | Redis private host. |
| `QUEUE_BULL_REDIS_PORT` | `${{n8n Main.QUEUE_BULL_REDIS_PORT}}` | Redis port. |
| `QUEUE_BULL_REDIS_USERNAME` | `${{n8n Main.QUEUE_BULL_REDIS_USERNAME}}` | Redis user. |
| `QUEUE_BULL_REDIS_PASSWORD` | `${{n8n Main.QUEUE_BULL_REDIS_PASSWORD}}` | Redis password. |
| `QUEUE_BULL_REDIS_DUALSTACK` | `${{n8n Main.QUEUE_BULL_REDIS_DUALSTACK}}` | Resolve Redis over IPv4 and IPv6 (Railway private network). |
| `N8N_ENCRYPTION_KEY` | `${{n8n Main.N8N_ENCRYPTION_KEY}}` | Encrypts stored credentials; identical on every n8n process. Never change after first boot. |
| `N8N_USER_MANAGEMENT_JWT_SECRET` | `${{n8n Main.N8N_USER_MANAGEMENT_JWT_SECRET}}` | Signs login sessions; identical on every n8n process. |
| `WEBHOOK_URL` | `${{n8n Main.WEBHOOK_URL}}` | Public base for webhook, form, chat and MCP URLs (the Gateway). |
| `N8N_PROXY_HOPS` | `${{n8n Main.N8N_PROXY_HOPS}}` | Trusted proxies in front of n8n (Railway edge + Gateway) for correct client IPs. |
| `N8N_DEFAULT_BINARY_DATA_MODE` | `${{n8n Main.N8N_DEFAULT_BINARY_DATA_MODE}}` | Binary data in Postgres so main, webhook and workers share files (filesystem mode is unsupported in queue mode). |
| `N8N_REINSTALL_MISSING_PACKAGES` | `${{n8n Main.N8N_REINSTALL_MISSING_PACKAGES}}` | Reinstall community nodes on boot (no shared volume between processes). |
| `GENERIC_TIMEZONE` | `${{n8n Main.GENERIC_TIMEZONE}}` | Default timezone for schedules (e.g. Europe/Istanbul). |
| `N8N_LOG_LEVEL` | `${{n8n Main.N8N_LOG_LEVEL}}` | Log level. |
| `N8N_DIAGNOSTICS_ENABLED` | `${{n8n Main.N8N_DIAGNOSTICS_ENABLED}}` | Disable anonymous telemetry. |
| `N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS` | `${{n8n Main.N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS}}` | Strict permissions on the n8n settings file. |

### n8n Worker

- **Source:** Docker image `n8nio/n8n:2.42.6`
- **Start command:** `tini -- /docker-entrypoint.sh worker --concurrency=10`
- **Healthcheck:** `/healthz/readiness` (timeout 300 s)
- **Public domain:** no (private network only)
- **TCP proxy:** none
- **Volume:** none
- **Restart policy:** ON_FAILURE (max 10 retries)
- **Replicas:** 1

| Variable | Value | Description |
|---|---|---|
| `PORT` | `5678` | Port of the worker health server (Railway healthcheck). |
| `QUEUE_HEALTH_CHECK_ACTIVE` | `true` | Expose /healthz and /healthz/readiness on the worker. |
| `QUEUE_HEALTH_CHECK_PORT` | `5678` | Worker health server port. |
| `N8N_RUNNERS_MODE` | `external` | Code nodes run in the separate n8n Task Runners service (n8n's production recommendation). |
| `N8N_RUNNERS_AUTH_TOKEN` | `${{secret(48, "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")}}` | Shared secret between this worker's task broker and the runners. |
| `N8N_RUNNERS_BROKER_LISTEN_ADDRESS` | `::` | Task broker listens on the private network (IPv4+IPv6). |
| `N8N_RUNNERS_BROKER_PORT` | `5679` | Task broker port. |
| `N8N_RUNNERS_TASK_REQUEST_TIMEOUT` | `60` | Seconds a Code node waits for a free runner. |
| `N8N_GRACEFUL_SHUTDOWN_TIMEOUT` | `30` | Seconds to finish running jobs on redeploy. |
| `EXECUTIONS_MODE` | `${{n8n Main.EXECUTIONS_MODE}}` | Queue mode: main/webhook enqueue executions in Redis, workers run them. |
| `DB_TYPE` | `${{n8n Main.DB_TYPE}}` | Database type. |
| `DB_POSTGRESDB_HOST` | `${{n8n Main.DB_POSTGRESDB_HOST}}` | Postgres private host. |
| `DB_POSTGRESDB_PORT` | `${{n8n Main.DB_POSTGRESDB_PORT}}` | Postgres port. |
| `DB_POSTGRESDB_DATABASE` | `${{n8n Main.DB_POSTGRESDB_DATABASE}}` | Postgres database. |
| `DB_POSTGRESDB_USER` | `${{n8n Main.DB_POSTGRESDB_USER}}` | Postgres user. |
| `DB_POSTGRESDB_PASSWORD` | `${{n8n Main.DB_POSTGRESDB_PASSWORD}}` | Postgres password. |
| `QUEUE_BULL_REDIS_HOST` | `${{n8n Main.QUEUE_BULL_REDIS_HOST}}` | Redis private host. |
| `QUEUE_BULL_REDIS_PORT` | `${{n8n Main.QUEUE_BULL_REDIS_PORT}}` | Redis port. |
| `QUEUE_BULL_REDIS_USERNAME` | `${{n8n Main.QUEUE_BULL_REDIS_USERNAME}}` | Redis user. |
| `QUEUE_BULL_REDIS_PASSWORD` | `${{n8n Main.QUEUE_BULL_REDIS_PASSWORD}}` | Redis password. |
| `QUEUE_BULL_REDIS_DUALSTACK` | `${{n8n Main.QUEUE_BULL_REDIS_DUALSTACK}}` | Resolve Redis over IPv4 and IPv6 (Railway private network). |
| `N8N_ENCRYPTION_KEY` | `${{n8n Main.N8N_ENCRYPTION_KEY}}` | Encrypts stored credentials; identical on every n8n process. Never change after first boot. |
| `N8N_USER_MANAGEMENT_JWT_SECRET` | `${{n8n Main.N8N_USER_MANAGEMENT_JWT_SECRET}}` | Signs login sessions; identical on every n8n process. |
| `WEBHOOK_URL` | `${{n8n Main.WEBHOOK_URL}}` | Public base for webhook, form, chat and MCP URLs (the Gateway). |
| `N8N_PROXY_HOPS` | `${{n8n Main.N8N_PROXY_HOPS}}` | Trusted proxies in front of n8n (Railway edge + Gateway) for correct client IPs. |
| `N8N_DEFAULT_BINARY_DATA_MODE` | `${{n8n Main.N8N_DEFAULT_BINARY_DATA_MODE}}` | Binary data in Postgres so main, webhook and workers share files (filesystem mode is unsupported in queue mode). |
| `N8N_REINSTALL_MISSING_PACKAGES` | `${{n8n Main.N8N_REINSTALL_MISSING_PACKAGES}}` | Reinstall community nodes on boot (no shared volume between processes). |
| `GENERIC_TIMEZONE` | `${{n8n Main.GENERIC_TIMEZONE}}` | Default timezone for schedules (e.g. Europe/Istanbul). |
| `N8N_LOG_LEVEL` | `${{n8n Main.N8N_LOG_LEVEL}}` | Log level. |
| `N8N_DIAGNOSTICS_ENABLED` | `${{n8n Main.N8N_DIAGNOSTICS_ENABLED}}` | Disable anonymous telemetry. |
| `N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS` | `${{n8n Main.N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS}}` | Strict permissions on the n8n settings file. |

### n8n Task Runners

- **Source:** Docker image `n8nio/runners:2.42.6`
- **Start command:** image default
- **Healthcheck:** `/healthz` (timeout 120 s)
- **Public domain:** no (private network only)
- **TCP proxy:** none
- **Volume:** none
- **Restart policy:** ON_FAILURE (max 10 retries)
- **Replicas:** 1

| Variable | Value | Description |
|---|---|---|
| `PORT` | `5680` | Launcher health port (Railway healthcheck). |
| `N8N_RUNNERS_TASK_BROKER_URI` | `http://${{n8n Worker.RAILWAY_PRIVATE_DOMAIN}}:5679` | Task broker of the paired worker. |
| `N8N_RUNNERS_AUTH_TOKEN` | `${{n8n Worker.N8N_RUNNERS_AUTH_TOKEN}}` | Must equal the worker's token. |
| `N8N_RUNNERS_AUTO_SHUTDOWN_TIMEOUT` | `15` | Stop idle JS/Python runners after N seconds (the launcher restarts them on demand). |
| `N8N_RUNNERS_MAX_CONCURRENCY` | `10` | Concurrent Code-node tasks per runner (matches worker concurrency). |
| `N8N_RUNNERS_LAUNCHER_LOG_LEVEL` | `info` | Launcher log level. |
| `GENERIC_TIMEZONE` | `${{n8n Main.GENERIC_TIMEZONE}}` | Timezone for Code nodes. |

### Ollama

- **Source:** GitHub repo `baranberkay96/n8n-ai-stack-railway`, root directory `/services/ollama` (Dockerfile build)
- **Start command:** image default
- **Healthcheck:** `/` (timeout 300 s)
- **Public domain:** no (private network only)
- **TCP proxy:** none
- **Volume:** `/root/.ollama`
- **Restart policy:** ON_FAILURE (max 10 retries)
- **Replicas:** 1

| Variable | Value | Description |
|---|---|---|
| `PORT` | `11434` | Ollama API port (private). |
| `OLLAMA_HOST` | `[::]:11434` | Bind address for the Ollama API (IPv4+IPv6). |
| `OLLAMA_PULL_MODELS` | `llama3.2:3b,nomic-embed-text:v1.5` | Models pulled on first boot (comma-separated). Chat model + embedding model for Qdrant RAG. |
| `OLLAMA_CONTEXT_LENGTH` | `8192` | Default context window (agents with tools need more than 4k). |
| `OLLAMA_KEEP_ALIVE` | `5m` | Unload idle models after this time to free RAM. |
| `OLLAMA_MAX_LOADED_MODELS` | `2` | Keep chat + embedding model loaded together. |

### Qdrant

- **Source:** Docker image `qdrant/qdrant:v1.19.2`
- **Start command:** image default
- **Healthcheck:** `/readyz` (timeout 300 s)
- **Public domain:** no (private network only)
- **TCP proxy:** none
- **Volume:** `/qdrant/storage`
- **Restart policy:** ON_FAILURE (max 10 retries)
- **Replicas:** 1

| Variable | Value | Description |
|---|---|---|
| `PORT` | `6333` | Qdrant REST port (gRPC 6334). |
| `QDRANT__SERVICE__HOST` | `::` | Listen on IPv4+IPv6. |
| `QDRANT__SERVICE__API_KEY` | `${{secret(40, "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")}}` | API key required for all Qdrant requests. |
| `QDRANT__TELEMETRY_DISABLED` | `true` | Disable Qdrant telemetry. |

### n8n Bootstrap

- **Source:** GitHub repo `baranberkay96/n8n-ai-stack-railway`, root directory `/services/bootstrap` (Dockerfile build)
- **Start command:** image default
- **Healthcheck:** none (no HTTP endpoint)
- **Public domain:** no (private network only)
- **TCP proxy:** none
- **Volume:** none
- **Restart policy:** ON_FAILURE (max 5 retries)
- **Replicas:** 1
- **Note:** One-shot job: seeds credentials + demo workflow on an empty instance, then exits (shows as completed).

| Variable | Value | Description |
|---|---|---|
| `N8N_MAIN_READY_URL` | `http://${{n8n Main.RAILWAY_PRIVATE_DOMAIN}}:5678/healthz/readiness` | Waits until n8n main has migrated the database. |
| `OLLAMA_BASE_URL` | `http://${{Ollama.RAILWAY_PRIVATE_DOMAIN}}:11434` | Base URL stored in the seeded Ollama credential. |
| `QDRANT_URL` | `http://${{Qdrant.RAILWAY_PRIVATE_DOMAIN}}:6333` | URL stored in the seeded Qdrant credential. |
| `QDRANT_API_KEY` | `${{Qdrant.QDRANT__SERVICE__API_KEY}}` | API key stored in the seeded Qdrant credential. |
| `DEMO_CHAT_MODEL` | `llama3.2:3b` | Model used by the seeded demo workflow. |
| `DB_TYPE` | `${{n8n Main.DB_TYPE}}` | Database type. |
| `DB_POSTGRESDB_HOST` | `${{n8n Main.DB_POSTGRESDB_HOST}}` | Postgres private host. |
| `DB_POSTGRESDB_PORT` | `${{n8n Main.DB_POSTGRESDB_PORT}}` | Postgres port. |
| `DB_POSTGRESDB_DATABASE` | `${{n8n Main.DB_POSTGRESDB_DATABASE}}` | Postgres database. |
| `DB_POSTGRESDB_USER` | `${{n8n Main.DB_POSTGRESDB_USER}}` | Postgres user. |
| `DB_POSTGRESDB_PASSWORD` | `${{n8n Main.DB_POSTGRESDB_PASSWORD}}` | Postgres password. |
| `N8N_ENCRYPTION_KEY` | `${{n8n Main.N8N_ENCRYPTION_KEY}}` | Encrypts stored credentials; identical on every n8n process. Never change after first boot. |
| `N8N_LOG_LEVEL` | `warn` | Keep CLI output short. |

### Postgres

- **Source:** Docker image `ghcr.io/railwayapp-templates/postgres-ssl:18`
- **Start command:** image default
- **Healthcheck:** none (no HTTP endpoint)
- **Public domain:** no (private network only)
- **TCP proxy:** none
- **Volume:** `/var/lib/postgresql/data`
- **Restart policy:** ON_FAILURE (max 10 retries)
- **Replicas:** 1
- **Note:** Copied unchanged from templates/_railway-base/postgres.json

| Variable | Value | Description |
|---|---|---|
| `PGDATA` | `/var/lib/postgresql/data/pgdata` | Location where the database will be initialized |
| `PGHOST` | `${{RAILWAY_PRIVATE_DOMAIN}}` | Railway Private Domain Name. |
| `PGPORT` | `5432` | Port to connect to Postgres. |
| `PGUSER` | `${{ POSTGRES_USER }}` | Required variable for Data panel |
| `PGDATABASE` | `${{POSTGRES_DB}}` | Required variable for the data panel. |
| `PGPASSWORD` | `${{POSTGRES_PASSWORD}}` | Required variable for Data panel |
| `POSTGRES_DB` | `railway` | Default database created when image is started. |
| `DATABASE_URL` | `postgresql://${{PGUSER}}:${{POSTGRES_PASSWORD}}@${{RAILWAY_PRIVATE_DOMAIN}}:5432/${{PGDATABASE}}` | URL to connect to Postgres database. |
| `POSTGRES_USER` | `postgres` | User to connect to Postgres DB |
| `SSL_CERT_DAYS` | `820` | SSL certificate expiry in days. |
| `POSTGRES_PASSWORD` | `${{ secret(32, "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ") }}` | Password to connect to DB |
| `RAILWAY_DEPLOYMENT_DRAINING_SECONDS` | `60` | Allow Postgres to cleanly shut down |

### Redis

- **Source:** Docker image `redis:8.2`
- **Start command:** `/bin/sh -c "rm -rf $RAILWAY_VOLUME_MOUNT_PATH/lost+found/ && exec docker-entrypoint.sh redis-server --requirepass $REDIS_PASSWORD --save 60 1 --dir $RAILWAY_VOLUME_MOUNT_PATH"`
- **Healthcheck:** none (no HTTP endpoint)
- **Public domain:** no (private network only)
- **TCP proxy:** none
- **Volume:** `/data`
- **Restart policy:** ON_FAILURE (max 10 retries)
- **Replicas:** 1
- **Note:** Copied unchanged from templates/_railway-base/redis.json

| Variable | Value | Description |
|---|---|---|
| `REDISHOST` | `${{RAILWAY_PRIVATE_DOMAIN}}` | Private network hostname of the Redis service, only resolvable from services in the same environment |
| `REDISPORT` | `6379` | Port that Redis listens on |
| `REDISUSER` | `default` | Username for authenticating with Redis |
| `REDIS_URL` | `redis://${{ REDISUSER }}:${{ REDIS_PASSWORD }}@${{ REDISHOST }}:${{ REDISPORT }}` | Connection string for connecting to Redis using the private network |
| `REDISPASSWORD` | `${{REDIS_PASSWORD}}` | Alias of REDIS_PASSWORD for clients that expect the unseparated name |
| `REDIS_PASSWORD` | `${{ secret(32, "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ") }}` | Randomly generated password for authenticating with Redis |

## Improvements over market templates

1. **Pinned n8n `2.42.6`** (stable channel) instead of `latest`; Redis/Postgres from the Railway base (no public TCP proxies, no Bitnami Redis).
2. **External task runners** (`n8nio/runners`) paired with the worker — n8n's production recommendation for v2; Code nodes no longer run inside the worker process.
3. **Dedicated webhook processor** behind a Gateway with n8n's documented routing; production webhooks, forms, chat and MCP triggers no longer compete with the editor.
4. **Binary data that works in queue mode** (`database` mode). The leader keeps the filesystem default, which n8n does not support across main and workers.
5. **AI services included**: Ollama with automatic first-boot pull of a chat and an embedding model (volume-backed, survives redeploys) and Qdrant with an API key and volume.
6. **Seeded credentials + demo workflow** (one-shot Bootstrap, from the upstream AI starter kit idea): "Ollama (Railway)" and "Qdrant (Railway)" credentials point at the private services; a demo chat workflow is ready to test.
7. Correct proxy handling (`N8N_PROXY_HOPS=2`) replacing the non-existent `N8N_TRUST_PROXY`; JWT secret shared across processes; readiness health checks on main, webhook and worker (`QUEUE_HEALTH_CHECK_ACTIVE=true`).
8. Community nodes reinstall automatically on every n8n process; telemetry off; timezone configurable.

## Scaling

- **Workers**: a worker and its runner form a pair (the runner connects to one worker's task broker). To add capacity, raise `--concurrency` first, then duplicate the **n8n Worker + n8n Task Runners** pair (new services; set the new runner's `N8N_RUNNERS_TASK_BROKER_URI` to the new worker). Plain Railway replicas of the worker would leave all but one replica without a runner (Code nodes would time out there). Alternative for code-free workloads: set `N8N_RUNNERS_MODE=internal` on the worker and use replicas.
- **Webhook processor**: stateless; replicas are fine for `/webhook` traffic. Keep one replica if you use MCP Server Trigger over SSE (sessions are per process).
- **Main**: single instance (multi-main is an n8n Enterprise feature).
- **Ollama**: scale vertically (RAM ≈ model size + context). Larger models (e.g. 7–8B) need ~6–8 GB RAM and are slow on CPU; for production-grade speed point the credentials at a hosted LLM API instead.

## Resource estimate

Prices: RAM $10/GB-month, vCPU $20/vCPU-month, volume $0.15/GB-month.

| Service | Idle RAM | Typical RAM | Typical vCPU | Volume |
|---|---|---|---|---|
| Gateway | 20 MB | 30 MB | 0.01 | — |
| n8n Main | 300 MB | 500 MB | 0.02 / 0.10 | — |
| n8n Webhook | 250 MB | 350 MB | 0.01 / 0.05 | — |
| n8n Worker | 300 MB | 700 MB | 0.02 / 0.30 | — |
| n8n Task Runners | 60 MB | 250 MB | 0.01 / 0.05 | — |
| Ollama (llama3.2:3b loaded) | 60 MB (model unloaded) | 3.2 GB | 0 / 0.50 avg (2–4 vCPU bursts while generating) | ~3 GB |
| Qdrant | 60 MB | 250 MB | 0.01 / 0.03 | ~1 GB |
| Postgres | 80 MB | 250 MB | 0.02 / 0.05 | ~2 GB (binary data lives here) |
| Redis | 10 MB | 40 MB | 0.01 | ~0.2 GB |
| n8n Bootstrap | 0 (exits) | 0 | 0 | — |
| **Total** | **≈ 1.15 GB** | **≈ 5.6 GB** | **≈ 0.1 / 1.1** | **≈ 6.2 GB** |

- **Idle:** 1.15 × $10 + 0.1 × $20 + 6.2 × $0.15 ≈ **$14/month**
- **Typical (model loaded most of the day, steady automations):** 5.6 × $10 + 1.1 × $20 + $0.9 ≈ **$79/month**
- Without local LLM use (Ollama idle, hosted LLM APIs): ≈ $25–30/month.
- **Minimum plan: Hobby** (Ollama needs > 1 GB RAM; Trial is too small). Hobby's 5 GB volume per service fits the two default models (~2.3 GB); larger local models need Pro.

## Verification checklist

1. Gateway `https://<domain>/gateway-healthz` → `ok`; n8n Main, n8n Webhook and n8n Worker pass `/healthz/readiness`; Task Runners `/healthz`; Qdrant `/readyz`; Ollama `/` → "Ollama is running".
2. Ollama logs: `pulling llama3.2:3b` … `success`, then `nomic-embed-text:v1.5` (first boot, a few minutes).
3. n8n Bootstrap logs `imported Ollama + Qdrant credentials and the demo workflow` and exits 0.
4. Open `https://<domain>/`, create the owner account, open *Local AI chat (Ollama) - demo*, click *Open chat* and send a message → answer from llama3.2 (execution appears under Executions, run by the worker).
5. Add a **Code** node (JavaScript `return [{json:{ok:true}}]` and a Python one) to any workflow and execute → succeeds via the Task Runners service (worker logs show the task broker; runner logs show the task).
6. Activate/publish a workflow with a Webhook trigger and `curl` its production URL → handled by **n8n Webhook** (check its logs), executed by the worker.
7. Build a small RAG flow: *Qdrant Vector Store* (credential "Qdrant (Railway)") + *Embeddings Ollama* (`nomic-embed-text:v1.5`) → insert a document, query it.
8. Redeploy every service → workflows, credentials and models persist; Bootstrap logs `workflows already exist, nothing to do`.

## Open questions

- **Not deployed yet**: verified against upstream source/docs for `n8n@2.42.6`, `n8nio/runners:2.42.6`, Ollama `v0.40.3`, Qdrant `v1.19.2`.
- **Runner pairing**: one runner service serves one worker. Duplicate the pair to scale; replicas of a worker are not covered by a single runner service.
- **Launcher health port binding**: if the runners' `/healthz` (port 5680) is unreachable on an IPv6-only legacy environment, remove that healthcheck; the runner connects outbound to the worker either way.
- **Webhook routing for new endpoint types**: if a future n8n release adds production endpoints beyond `/webhook`, `/webhook-waiting`, `/form`, `/form-waiting`, `/mcp`, add them to the Gateway regex (or set `N8N_DISABLE_PRODUCTION_MAIN_PROCESS=false`).
- **CPU-only inference** is slow for larger models; the template sizes for a 3B model.
- **Bootstrap import format**: relies on `n8n import:credentials` encrypting plain JSON `data` (present in 2.42.6 source). If the import fails, the job retries up to 5 times and the rest of the stack is unaffected.
- **n8n license**: n8n is distributed under the Sustainable Use License (fair-code); self-hosting for your own business is permitted, reselling n8n as a hosted service is not.
