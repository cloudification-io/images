# syntax=docker/dockerfile:1
ARG OPENSTACK_RELEASE=2025.1
ARG BASE_TAG=${OPENSTACK_RELEASE}-ubuntu_noble

FROM quay.io/airshipit/nova:${BASE_TAG} AS upstream

FROM quay.io/airshipit/venv_builder:${BASE_TAG} AS build
ENV PATH=/var/lib/openstack/bin:$PATH
COPY --from=upstream /var/lib/openstack /var/lib/openstack
RUN uv pip install -c /upper-constraints.txt jaeger-client

ARG OPENSTACK_RELEASE
COPY patches/${OPENSTACK_RELEASE}/nova-ovmf-mmio.patch /tmp/nova-ovmf-mmio.patch
RUN cd /var/lib/openstack/lib/python3.12/site-packages \
    && git apply --check /tmp/nova-ovmf-mmio.patch \
    && git apply /tmp/nova-ovmf-mmio.patch

FROM quay.io/airshipit/nova:${BASE_TAG}
COPY --from=build --link /var/lib/openstack /var/lib/openstack
RUN apt-get update \
    && apt-get install -y --no-install-recommends ovmf qemu-block-extra \
    && rm -rf /var/lib/apt/lists/*
