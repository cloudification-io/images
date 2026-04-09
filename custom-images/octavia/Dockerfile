ARG OPENSTACK_RELEASE=2025.1
ARG BASE_TAG=${OPENSTACK_RELEASE}-ubuntu_noble

FROM quay.io/airshipit/octavia:${BASE_TAG}

RUN unset PIP_INDEX_URL ; unset PIP_EXTRA_INDEX_URL ; unset PIP_TRUSTED_HOST ; pip install python-openstackclient redis
