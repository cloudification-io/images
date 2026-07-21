# syntax=docker/dockerfile:1
ARG OPENSTACK_RELEASE=2026.1
ARG BASE_TAG=${OPENSTACK_RELEASE}-ubuntu_noble

FROM quay.io/airshipit/horizon:${BASE_TAG} AS upstream

FROM quay.io/airshipit/venv_builder:${BASE_TAG} AS build
ENV PATH=/var/lib/openstack/bin:$PATH
COPY --from=upstream /var/lib/openstack /var/lib/openstack

ARG OPENSTACK_RELEASE
ARG HORIZON_REF=stable/${OPENSTACK_RELEASE}-c12n
ARG CLOUDKITTY_DASHBOARD_REF=stable/${OPENSTACK_RELEASE}-c12n
ARG OCTAVIA_DASHBOARD_REF=stable/${OPENSTACK_RELEASE}
ARG BARBICAN_UI_REF=main
ARG CACHE_BUST=local

# version the fork as the horizon=== pin so the constraints stay intact;
# left to pbr's git-tag fallback the version would not satisfy the pin
RUN echo "Cache bust: ${CACHE_BUST}" \
 && PBR_VERSION=$(sed -n 's/^horizon===//p' /upper-constraints.txt) \
    uv pip install --build-constraint /upper-constraints.txt -c /upper-constraints.txt \
        --reinstall-package horizon \
        "horizon @ git+https://github.com/cloudification-io/horizon.git@${HORIZON_REF}"

RUN uv pip install -c /upper-constraints.txt \
        jaeger-client \
        python-cloudkittyclient \
        masakari-dashboard \
        designate-dashboard \
        heat-dashboard \
        "octavia-dashboard @ git+https://opendev.org/openstack/octavia-dashboard.git@${OCTAVIA_DASHBOARD_REF}" \
        "cloudkitty-dashboard @ git+https://github.com/cloudification-io/cloudkitty-dashboard.git@${CLOUDKITTY_DASHBOARD_REF}" \
        "barbican-ui @ git+https://github.com/cloudification-io/barbican-ui.git@${BARBICAN_UI_REF}" \
 && uv pip install oslo.policy==4.3.0

FROM quay.io/airshipit/horizon:${BASE_TAG}
# clear the base tree first: COPY cannot delete files, and dist-info of packages
# replaced in the build stage would otherwise shadow the new versions
RUN rm -rf /var/lib/openstack
COPY --from=build --link /var/lib/openstack /var/lib/openstack
