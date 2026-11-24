FROM alpine:3.24

ARG CACHE_BUST=local

RUN echo "Cache bust: ${CACHE_BUST}" && \
    apk upgrade --no-cache && \
    apk add --no-cache net-snmp && \
    addgroup -S -g 10001 snmptrapd && \
    adduser -S -G snmptrapd -u 10001 snmptrapd && \
    chown 10001:10001 /var/lib/net-snmp

USER 10001:10001

EXPOSE 1162/udp

CMD ["snmptrapd", "-f", "-Lo", "udp:1162"]
