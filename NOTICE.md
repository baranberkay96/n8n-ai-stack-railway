# Notice

## Upstream software

| Software | License | Images used (publisher) |
|---|---|---|
| n8n | Sustainable Use License (fair-code); `.ee` files under the n8n Enterprise License | `n8nio/n8n:2.42.6`, `n8nio/runners:2.42.6` (n8n GmbH) |
| Ollama | MIT — Copyright (c) Ollama | `ollama/ollama:0.40.3` (Ollama) |
| Qdrant | Apache-2.0 | `qdrant/qdrant:v1.19.2` (Qdrant) |
| nginx | BSD-2-Clause | `nginx:1.30.5-alpine` (Docker Official Image) |
| PostgreSQL | PostgreSQL License | `ghcr.io/railwayapp-templates/postgres-ssl:18` (Railway) |
| Redis | RSALv2 / SSPLv1 / AGPLv3 (Redis 8 tri-license) | `redis:8.2` (Docker Official Image) |
| Models pulled at runtime | Llama 3.2 Community License (`llama3.2:3b`, Meta); Apache-2.0 (`nomic-embed-text:v1.5`, Nomic AI) | Ollama library |

## Verified against

| What | Upstream file | Ref | URL | Checked |
|---|---|---|---|---|
| Stable release | GitHub releases (`stable` → `n8n@2.42.6`, `beta` → 2.43.x) | `n8n@2.42.6` | https://github.com/n8n-io/n8n/releases | 2026-10-11 |
| Image entrypoint / user | `docker/images/n8n/Dockerfile`, `docker/images/n8n/docker-entrypoint.sh` | `n8n@2.42.6` | https://github.com/n8n-io/n8n/tree/n8n%402.42.6/docker/images/n8n | 2026-10-11 |
| Task runner image, launcher config, health ports | `docker/images/runners/Dockerfile`, `README.md`, `n8n-task-runners.json`; launcher `docs/setup.md` (v1.5.1) | `n8n@2.42.6` | https://github.com/n8n-io/n8n/tree/n8n%402.42.6/docker/images/runners | 2026-10-11 |
| Runner env (mode, broker address/port, token, timeouts) | `packages/@n8n/config/src/configs/runners.config.ts` | `n8n@2.42.6` | same repo | 2026-10-11 |
| Queue / worker health env (`QUEUE_HEALTH_CHECK_*`, `QUEUE_BULL_REDIS_*`, dual-stack) | `packages/@n8n/config/src/configs/scaling-mode.config.ts` | `n8n@2.42.6` | same repo | 2026-10-11 |
| Endpoints served by the webhook process; `N8N_DISABLE_PRODUCTION_MAIN_PROCESS` | `packages/cli/src/abstract-server.ts`, `packages/@n8n/config/src/configs/endpoints.config.ts` | `n8n@2.42.6` | same repo | 2026-10-11 |
| Listen address / port / proxy hops / editor URL | `packages/@n8n/config/src/index.ts` | `n8n@2.42.6` | same repo | 2026-10-11 |
| Binary data modes (`database` default in queue mode) | `packages/core/src/binary-data/binary-data.config.ts` | `n8n@2.42.6` | same repo | 2026-10-11 |
| Main skips task runner when manual executions are offloaded; deprecations | `packages/cli/src/commands/start.ts`, `packages/cli/src/deprecation/deprecation.service.ts` | `n8n@2.42.6` | same repo | 2026-10-11 |
| Credential import encrypts plain `data` | `packages/cli/src/commands/import/credentials.ts` | `n8n@2.42.6` | same repo | 2026-10-11 |
| Credential field names | `packages/@n8n/nodes-langchain/credentials/OllamaApi.credentials.ts`, `QdrantApi.credentials.ts` | `n8n@2.42.6` | same repo | 2026-10-11 |
| Queue mode, load-balancer routing, multi-main availability | Queue mode docs | — | https://docs.n8n.io/hosting/scaling/queue-mode/ | 2026-10-11 |
| External vs internal runners, one runner per worker | Task runners docs | — | https://docs.n8n.io/hosting/configuration/task-runners/ | 2026-10-11 |
| AI starter kit service set | `docker-compose.yml`, `.env.example`, `n8n/demo-data/**` | commit `662bd88` | https://github.com/n8n-io/self-hosted-ai-starter-kit | 2026-10-11 |
| Qdrant bind host, health endpoints exempt from API key | `config/config.yaml`, `src/actix/mod.rs` | `v1.19.2` | https://github.com/qdrant/qdrant/tree/v1.19.2 | 2026-10-11 |
| Ollama release / image | GitHub releases, Docker Hub tag | `v0.40.3` | https://github.com/ollama/ollama/releases | 2026-10-11 |

## Adapted code

| Our file | Source | Copyright / license | Changes |
|---|---|---|---|
| `services/bootstrap/demo-workflow.json.tmpl`, `services/bootstrap/bootstrap.sh` (seed approach) | `n8n-io/self-hosted-ai-starter-kit`: `n8n/demo-data/workflows/srOnR8PAY3u4RSwb.json` and the `n8n-import` service in `docker-compose.yml` | Copyright 2024-present n8n GmbH — Apache License 2.0 | Workflow re-written with new IDs, a configurable model and a credential pointing at the Railway Ollama service; credentials are generated at runtime as plain JSON (the kit's encrypted demo credentials are not used); waits for main readiness; skips when workflows exist |
| `services/ollama/railway-entrypoint.sh` (first-boot pull) | Idea of the kit's `ollama-pull-llama` init container | Copyright 2024-present n8n GmbH — Apache License 2.0 | Re-implemented as an in-container wrapper (Railway volumes cannot be shared with an init container); multiple models; skip if present |
| `services/gateway/*` | Written for this template from n8n's documented queue-mode routing | — | — |

## Reference only (not copied)

- `_upstream/derekcheungsa__n8n-railway-custom` — no license: read only (it builds n8n from npm with build-time credentials and legacy basic auth). Nothing copied.
- Marketplace templates `n8n-with-workers` ("N8N (w/ workers)"), `Xx4_lu` ("flowise-with-n8n-ai-automation"), `9router-ai-gateway`: no license; reviewed for structure. No files or text copied.

## Trademarks

"n8n" is a trademark of n8n GmbH; "Ollama", "Qdrant", "Llama" and "Railway" belong to their respective owners. This is a community template and is not affiliated with or endorsed by them.
