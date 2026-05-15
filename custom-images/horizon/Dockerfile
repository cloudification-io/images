# syntax=docker/dockerfile:1
ARG OPENSTACK_RELEASE=2026.1
ARG BASE_TAG=${OPENSTACK_RELEASE}-ubuntu_noble

FROM quay.io/airshipit/horizon:${BASE_TAG} AS upstream

FROM quay.io/airshipit/venv_builder:${BASE_TAG} AS build
ENV PATH=/var/lib/openstack/bin:$PATH
COPY --from=upstream /var/lib/openstack /var/lib/openstack

ARG OPENSTACK_RELEASE
ARG CLOUDKITTY_DASHBOARD_REF=stable/${OPENSTACK_RELEASE}
ARG OCTAVIA_DASHBOARD_REF=stable/${OPENSTACK_RELEASE}
ARG BARBICAN_UI_REF=main

RUN uv pip install -c /upper-constraints.txt \
        jaeger-client \
        python-cloudkittyclient \
        masakari-dashboard \
        designate-dashboard \
        heat-dashboard \
        "octavia-dashboard @ git+https://opendev.org/openstack/octavia-dashboard.git@${OCTAVIA_DASHBOARD_REF}" \
        "cloudkitty-dashboard @ git+https://opendev.org/openstack/cloudkitty-dashboard.git@${CLOUDKITTY_DASHBOARD_REF}" \
        "barbican-ui @ git+https://github.com/cloudification-io/barbican-ui.git@${BARBICAN_UI_REF}" \
 && uv pip install oslo.policy==4.3.0

FROM quay.io/airshipit/horizon:${BASE_TAG}
COPY --from=build --link /var/lib/openstack /var/lib/openstack
