# One-shot job: on a fresh instance, imports an Ollama credential, a Qdrant credential and a
# demo chat workflow into n8n, then exits. Idea and demo flow adapted from
# n8n-io/self-hosted-ai-starter-kit (Apache-2.0), see NOTICE.md.
FROM n8nio/n8n:2.42.6

COPY --chown=node:node bootstrap.sh /home/node/bootstrap.sh
COPY --chown=node:node demo-workflow.json.tmpl /home/node/demo-workflow.json.tmpl

ENTRYPOINT ["tini", "--", "/bin/sh", "/home/node/bootstrap.sh"]
