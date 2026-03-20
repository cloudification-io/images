FROM quay.io/airshipit/openvswitch:latest-ubuntu_noble

RUN apt-get update && \
    apt-get install -y iproute2 iptables && \
    rm -rf /var/lib/apt/lists/*
