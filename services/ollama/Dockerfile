# Ollama with an automatic first-boot model pull for Railway (CPU inference).
FROM ollama/ollama:0.40.3

COPY railway-entrypoint.sh /usr/local/bin/railway-entrypoint.sh
RUN chmod 0755 /usr/local/bin/railway-entrypoint.sh

ENV OLLAMA_HOST=[::]:11434
EXPOSE 11434
ENTRYPOINT ["/usr/local/bin/railway-entrypoint.sh"]
