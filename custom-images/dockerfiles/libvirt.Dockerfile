ARG OPENSTACK_RELEASE=2025.1
ARG BASE_TAG=${OPENSTACK_RELEASE}-ubuntu_noble

FROM quay.io/airshipit/libvirt:${BASE_TAG}

RUN groupmod -g 109 kvm
