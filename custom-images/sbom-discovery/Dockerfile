FROM alpine:3.24

RUN apk upgrade --no-cache && \
    apk add --no-cache \
        ca-certificates \
        jq \
        kubectl

RUN addgroup -S sbom && \
    adduser -S -G sbom -u 10001 sbom

USER 10001:10001

CMD ["/bin/sh"]
