# syntax=docker/dockerfile:1
ARG OPENSTACK_RELEASE=2025.1
ARG BASE_TAG=${OPENSTACK_RELEASE}-ubuntu_noble

FROM quay.io/airshipit/barbican:${BASE_TAG} AS upstream

FROM quay.io/airshipit/venv_builder:${BASE_TAG} AS build
ENV PATH=/var/lib/openstack/bin:$PATH
COPY --from=upstream /var/lib/openstack /var/lib/openstack
RUN uv pip install -c /upper-constraints.txt jaeger-client

FROM quay.io/airshipit/barbican:${BASE_TAG}
COPY --from=build --link /var/lib/openstack /var/lib/openstack
