ARG OPENSTACK_RELEASE=2025.1
ARG BASE_TAG=${OPENSTACK_RELEASE}-ubuntu_noble

FROM quay.io/airshipit/barbican:${BASE_TAG}
ARG OPENSTACK_RELEASE
ARG CONSTRAINTS=https://raw.githubusercontent.com/openstack/requirements/stable/${OPENSTACK_RELEASE}/upper-constraints.txt

RUN pip install -c ${CONSTRAINTS} jaeger-client
