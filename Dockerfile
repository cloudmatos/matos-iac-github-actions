FROM cloudmatos/matos-iac-scan:latest

RUN apt-get update && \
    apt-get install -y --no-install-recommends bash jq curl && \
    rm -rf /var/lib/apt/lists/*

COPY ./entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

COPY ./ /app

ENTRYPOINT ["/entrypoint.sh"]
