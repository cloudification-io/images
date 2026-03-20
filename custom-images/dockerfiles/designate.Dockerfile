ARG OPENSTACK_RELEASE=2025.1
ARG BASE_TAG=${OPENSTACK_RELEASE}-ubuntu_noble

FROM quay.io/airshipit/designate:${BASE_TAG}

RUN apt-get update && \
    apt-get install -y --no-install-recommends bind9 && \
    rm -rf /var/lib/apt/lists/*
