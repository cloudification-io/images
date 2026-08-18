ARG OPENSTACK_RELEASE=2026.1
ARG BASE_TAG=${OPENSTACK_RELEASE}-ubuntu-noble

FROM quay.io/openstack.kolla/gnocchi-metricd:${BASE_TAG}

USER root
RUN pip install "numpy>=2.3.2,<3"
USER gnocchi
