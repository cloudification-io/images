FROM docker.io/library/golang:1.21.5 AS build
ARG COREDNS_VERSION=v1.11.1
ARG ALTERNATE_VERSION=v0.2.7
ARG K8S_GATEWAY_VERSION=v0.4.0

WORKDIR /go/src/coredns

RUN git clone --depth=1 --branch ${COREDNS_VERSION} https://github.com/coredns/coredns.git .

COPY plugin.cfg.${COREDNS_VERSION} plugin.cfg

RUN go get github.com/coredns/alternate@${ALTERNATE_VERSION}
RUN go get github.com/ori-edge/k8s_gateway@${K8S_GATEWAY_VERSION}
RUN make gen && make
# Check if plugins are installed
RUN ./coredns -plugins | grep alternate
RUN ./coredns -plugins | grep k8s_gateway

FROM debian:bullseye-slim
COPY --from=build /go/src/coredns/coredns /coredns

RUN apt-get update -y && \
    apt-get install --no-install-recommends -y \
    iputils-ping \
    dnsutils \
    ca-certificates && \
    apt autoclean -y && \
    apt autopurge -y && \
    rm -rf /var/lib/apt/lists/* && \
    rm /var/log/apt/* /var/log/dpkg.log

EXPOSE 53 53/udp
ENTRYPOINT ["/coredns"]
