FROM cloudmatos/matos-iac-scan:latest

RUN apk add bash && \
    apk add jq && apk add curl

COPY ./entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

COPY ./ /app

ENTRYPOINT ["/entrypoint.sh"]