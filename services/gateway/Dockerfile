# n8n gateway for Railway: one public origin that sends production webhook traffic to the
# webhook processor and everything else (editor, REST API, push, test webhooks) to n8n main,
# as described in n8n's queue-mode load-balancer guidance.
FROM nginx:1.30.5-alpine

# 15-local-resolvers.envsh exports NGINX_LOCAL_RESOLVERS from /etc/resolv.conf (IPv6-aware).
# The envsubst filter keeps nginx runtime variables ($host, $http_upgrade, ...) untouched.
ENV NGINX_ENTRYPOINT_LOCAL_RESOLVERS=1 \
    NGINX_ENVSUBST_FILTER="^(PORT|N8N_GW_|NGINX_)" \
    PORT=8080 \
    NGINX_CLIENT_MAX_BODY_SIZE=200M \
    NGINX_PROXY_TIMEOUT=3600s

RUN rm -f /etc/nginx/conf.d/default.conf
COPY snippets/ /etc/nginx/snippets/
COPY templates/ /etc/nginx/templates/

EXPOSE 8080
