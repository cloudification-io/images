# syntax=docker/dockerfile:1
ARG OPENSTACK_RELEASE=2025.1
ARG BASE_TAG=${OPENSTACK_RELEASE}-ubuntu_noble

FROM quay.io/airshipit/neutron:${BASE_TAG} AS upstream

FROM quay.io/airshipit/venv_builder:${BASE_TAG} AS build
ENV PATH=/var/lib/openstack/bin:$PATH
COPY --from=upstream /var/lib/openstack /var/lib/openstack
ARG OPENSTACK_RELEASE
ARG NEUTRON_FWAAS_REF=stable/${OPENSTACK_RELEASE}
ARG NETWORKING_L2GW_REF=stable/${OPENSTACK_RELEASE}
ARG CACHE_BUST=local

RUN echo "Cache bust: ${CACHE_BUST}" \
 && uv pip install -c /upper-constraints.txt \
        jaeger-client \
        "neutron-fwaas @ git+https://github.com/openstack/neutron-fwaas.git@${NEUTRON_FWAAS_REF}" \
        "networking-l2gw @ git+https://opendev.org/x/networking-l2gw.git@${NETWORKING_L2GW_REF}"


FROM quay.io/airshipit/neutron:${BASE_TAG}
COPY --from=build --link /var/lib/openstack /var/lib/openstack
