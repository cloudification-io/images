ARG OPENSTACK_RELEASE=2025.1
ARG BASE_TAG=${OPENSTACK_RELEASE}-ubuntu_noble

FROM quay.io/airshipit/horizon:${BASE_TAG}
ARG OPENSTACK_RELEASE
ARG CONSTRAINTS=https://raw.githubusercontent.com/openstack/requirements/stable/${OPENSTACK_RELEASE}/upper-constraints.txt
ARG CONSTRAINTS_2024_1=https://opendev.org/openstack/requirements/raw/branch/unmaintained/2024.1/upper-constraints.txt
ARG CLOUDKITTY_DASHBOARD_REF=stable/${OPENSTACK_RELEASE}
ARG BARBICAN_UI_REF=main

RUN pip install -c ${CONSTRAINTS} jaeger-client

RUN apt-get update && \
    apt-get install -y --no-install-recommends build-essential python3-dev git && \
    pip install -c ${CONSTRAINTS_2024_1} octavia-dashboard && \
    pip install -c ${CONSTRAINTS} \
        "cloudkitty-dashboard @ git+https://opendev.org/openstack/cloudkitty-dashboard.git@${CLOUDKITTY_DASHBOARD_REF:-stable/${OPENSTACK_RELEASE}}" \
        "barbican-ui @ git+https://github.com/cloudification-io/barbican-ui.git@${BARBICAN_UI_REF}" && \
    apt-get purge -y build-essential python3-dev && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

RUN pip install -c ${CONSTRAINTS} python-cloudkittyclient
RUN pip install -c ${CONSTRAINTS} masakari-dashboard
RUN pip install -c ${CONSTRAINTS} designate-dashboard
RUN pip install -c ${CONSTRAINTS} heat-dashboard
RUN pip install oslo.policy==4.3.0
