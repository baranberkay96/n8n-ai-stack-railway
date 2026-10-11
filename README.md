# Deploy and Host n8n with Railway

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/n8n-2-ai-agent-stack-ollama-qdrant)

n8n is a fair-code workflow automation platform with a visual editor, 400+ integrations and native AI agent nodes. This community template runs n8n 2 in queue mode with a webhook processor, workers, isolated task runners, a local Ollama LLM and a Qdrant vector database, all on one private Railway network.

## About Hosting n8n

A single n8n container works for experiments, but production automations need more: Postgres instead of SQLite, Redis-backed queue mode so workers execute runs while the editor stays responsive, a webhook processor for incoming traffic, and task runners that execute Code nodes outside the n8n process. AI agent workflows add a model server and a vector store for memory and retrieval. This template wires all of these with generated secrets, readiness checks and persistent volumes, pulls a small open model on first boot, and seeds ready-made Ollama and Qdrant credentials plus a demo chat workflow, so you can build private AI agents without sending data to external LLM APIs.

## Common Use Cases

- AI agents and chatbots that run on a local open model (Ollama) with tool calling
- Retrieval-augmented workflows that store and search embeddings in Qdrant
- High-volume webhook and API automations processed by queue workers
- Scheduled data syncs between SaaS tools, databases and internal APIs
- Exposing workflows as MCP servers or chat endpoints for other AI tools

## Dependencies for n8n Hosting

- n8n main, webhook processor and worker (`n8nio/n8n`)
- n8n task runners (`n8nio/runners`) for Code nodes
- PostgreSQL (workflows, credentials, executions, binary data)
- Redis (BullMQ execution queue)
- Ollama (local LLM and embeddings) and Qdrant (vector store)
- nginx gateway (routes production webhooks to the webhook processor)

### Deployment Dependencies

- n8n repository: https://github.com/n8n-io/n8n
- Queue mode: https://docs.n8n.io/hosting/scaling/queue-mode/
- Task runners: https://docs.n8n.io/hosting/configuration/task-runners/
- Binary data configuration: https://docs.n8n.io/hosting/configuration/environment-variables/binary-data/
- n8n Self-hosted AI Starter Kit: https://github.com/n8n-io/self-hosted-ai-starter-kit
- Ollama: https://github.com/ollama/ollama · Qdrant: https://qdrant.tech/documentation/

### Implementation Details

| Service | Image | Role | Public |
|---|---|---|---|
| Gateway | nginx 1.30 (repo build) | Routes `/webhook`, `/webhook-waiting`, `/form`, `/form-waiting`, `/mcp` to the webhook processor, everything else to main | **yes** |
| n8n Main | `n8nio/n8n:2.42.6` | Editor, REST API, triggers, test executions (offloaded to workers) | no |
| n8n Webhook | `n8nio/n8n:2.42.6` (`n8n webhook`) | Production webhooks, forms, chat and MCP triggers | no |
| n8n Worker | `n8nio/n8n:2.42.6` (`n8n worker --concurrency=10`) | Executes workflows from the Redis queue | no |
| n8n Task Runners | `n8nio/runners:2.42.6` | Runs JavaScript and Python Code nodes for the worker | no |
| Ollama | `ollama/ollama:0.40.3` (repo build) | Local LLM + embeddings; pulls `llama3.2:3b` and `nomic-embed-text:v1.5` on first boot | no |
| Qdrant | `qdrant/qdrant:v1.19.2` | Vector store (API key protected) | no |
| n8n Bootstrap | `n8nio/n8n:2.42.6` (repo build) | One-shot: seeds Ollama/Qdrant credentials and a demo workflow, then exits | no |
| Postgres / Redis | Railway base images | Database / queue | no |

**First login**

1. Wait until n8n Main is healthy and the Ollama logs show both models pulled (first boot downloads about 2.3 GB).
2. Open the Gateway URL and create the owner account (n8n's first-run setup; do this right after deploying).
3. Open the workflow *Local AI chat (Ollama) - demo* and click *Open chat*. Credentials *Ollama (Railway)* and *Qdrant (Railway)* are already configured for the private services.

**Scaling workers:** raise `--concurrency` in the worker start command first. For more workers, duplicate the **n8n Worker + n8n Task Runners** pair and point the new runner's `N8N_RUNNERS_TASK_BROKER_URI` at the new worker; each worker needs its own runner. The webhook processor can run multiple replicas.

**Models:** change `OLLAMA_PULL_MODELS` on the Ollama service (comma-separated) and redeploy to pull more models. Railway has no GPUs, so keep local models small or use a hosted model API in the same workflows.

**Custom domain:** add it to the Gateway, then update `WEBHOOK_URL` and `N8N_EDITOR_BASE_URL` on n8n Main (other n8n services reference these values).

**Pinning and upgrading:** n8n images are pinned to `2.42.6`. To upgrade, back up Postgres and set the same new tag on n8n Main, n8n Webhook, n8n Worker, n8n Task Runners and the Bootstrap Dockerfile (runner and n8n versions must match). Ollama and Qdrant are pinned separately.

**License note:** n8n is fair-code under the Sustainable Use License: free to self-host for your own business, not to resell as a hosted service. Enterprise features (`.ee` code) need an n8n license.

### Why Deploy n8n on Railway?

Railway runs the full n8n queue-mode stack, a local LLM and a vector database in one project on a private network with managed HTTPS and persistent volumes. You get a production-shaped AI automation platform without managing servers, can add workers or memory from the dashboard, and roll back any deploy in one click. This is a community template and is not affiliated with n8n GmbH, Ollama or Qdrant.
