ARG OPENSTACK_RELEASE=2025.1
ARG BASE_TAG=${OPENSTACK_RELEASE}-ubuntu_noble

FROM quay.io/airshipit/libvirt:${BASE_TAG}

RUN groupmod -g 109 kvm

# swtpm for Nova vTPM support. The tss user must match NOVA_TSS_UID/GID=42434
# in the airshipit nova image (shared /var/lib/libvirt hostPath).
ARG TSS_USER=tss
ARG TSS_UID=42434
ARG TSS_GID=42434
RUN apt-get update \
    && apt-get install -y --no-install-recommends swtpm swtpm-tools \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd -g ${TSS_GID} ${TSS_USER} \
    && useradd -u ${TSS_UID} -g ${TSS_USER} -M -d /var/lib/swtpm -s /usr/sbin/nologin -c "${TSS_USER} user" ${TSS_USER} \
    && mkdir -p /var/lib/swtpm-localca \
    && chown ${TSS_USER}:${TSS_USER} /var/lib/swtpm-localca
