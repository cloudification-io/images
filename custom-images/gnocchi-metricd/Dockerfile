ARG OPENSTACK_RELEASE=2026.1
ARG BASE_TAG=${OPENSTACK_RELEASE}-ubuntu-noble

FROM quay.io/openstack.kolla/gnocchi-metricd:${BASE_TAG}

USER root
RUN pip install "numpy>=2.3.2,<3"
RUN apt-get update \
    && apt-get remove -y \
        build-essential \
        g++ \
        g++-13 \
        g++-13-x86-64-linux-gnu \
        g++-x86-64-linux-gnu \
        libc6-dev \
        libexpat1-dev \
        libicu-dev \
        libpcre2-dev \
        libpython3-dev \
        libpython3.12-dev \
        libstdc++-13-dev \
        libxml2-dev \
        libxslt1-dev \
        linux-libc-dev \
        python3-dev \
        python3.12-dev \
        zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*
USER gnocchi
