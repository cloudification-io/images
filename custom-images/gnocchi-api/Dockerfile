ARG OPENSTACK_RELEASE=2026.1
ARG BASE_TAG=${OPENSTACK_RELEASE}-ubuntu-noble

FROM quay.io/openstack.kolla/gnocchi-api:${BASE_TAG}

ARG PYJWT_VERSION=2.14.0

RUN /var/lib/kolla/venv/bin/python -m pip install \
        --no-cache-dir uwsgi "numpy>=2.3.2,<3" \
    && /var/lib/kolla/venv/bin/python -m pip install \
        --no-cache-dir --no-deps "PyJWT==${PYJWT_VERSION}" \
    && /var/lib/kolla/venv/bin/python -m pip check

ARG OPENSTACK_RELEASE
COPY patches/${OPENSTACK_RELEASE}/gnocchi-restore-ended-resources.patch /tmp/gnocchi-restore-ended-resources.patch
RUN cd /var/lib/kolla/venv/lib/python3.12/site-packages \
    && git apply /tmp/gnocchi-restore-ended-resources.patch \
    && rm /tmp/gnocchi-restore-ended-resources.patch

RUN apt-get purge -y \
        build-essential \
        gcc \
        g++ \
        cpp \
        make \
        binutils \
        dpkg-dev \
        pkg-config \
        libffi-dev \
        libpcre2-dev \
        libpq-dev \
        librados-dev \
        libssl-dev \
        libxml2-dev \
        libxslt1-dev \
        libyaml-dev \
        zlib1g-dev \
        python3-dev \
        linux-libc-dev \
    && rm -rf /var/lib/apt/lists/*
