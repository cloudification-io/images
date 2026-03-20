ARG OPENSTACK_RELEASE=2025.1
ARG BASE_TAG=${OPENSTACK_RELEASE}-ubuntu_noble

FROM quay.io/airshipit/nova:${BASE_TAG}
ARG OPENSTACK_RELEASE
ARG CONSTRAINTS=https://raw.githubusercontent.com/openstack/requirements/stable/${OPENSTACK_RELEASE}/upper-constraints.txt

RUN pip install -c ${CONSTRAINTS} jaeger-client
RUN apt-get update && apt-get install -y ovmf

COPY patches/${OPENSTACK_RELEASE}/nova-ovmf-mmio.patch /tmp/nova-ovmf-mmio.patch
RUN apt-get update && apt-get install -y git && \
    cd /var/lib/openstack/lib/python3.12/site-packages && \
    git apply --stat /tmp/nova-ovmf-mmio.patch && \
    git apply --check /tmp/nova-ovmf-mmio.patch && \
    git apply /tmp/nova-ovmf-mmio.patch
