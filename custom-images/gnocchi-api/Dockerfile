ARG OPENSTACK_RELEASE=2025.1
ARG BASE_TAG=${OPENSTACK_RELEASE}-ubuntu-noble

FROM quay.io/openstack.kolla/gnocchi-api:${BASE_TAG}

RUN pip install uwsgi "numpy>=2.3.2,<3"
