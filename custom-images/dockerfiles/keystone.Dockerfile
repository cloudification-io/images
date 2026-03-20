ARG OPENSTACK_RELEASE=2025.1
ARG BASE_TAG=${OPENSTACK_RELEASE}-ubuntu_noble

FROM quay.io/airshipit/keystone:${BASE_TAG}
ARG OPENSTACK_RELEASE
ARG CONSTRAINTS=https://raw.githubusercontent.com/openstack/requirements/stable/${OPENSTACK_RELEASE}/upper-constraints.txt

RUN pip install -c ${CONSTRAINTS} jaeger-client
RUN apt-get update && apt-get install -y libapache2-mod-auth-openidc && a2enmod auth_openidc
