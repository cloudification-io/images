ARG OPENSTACK_RELEASE=2025.1
ARG BASE_TAG=${OPENSTACK_RELEASE}-ubuntu_noble

FROM quay.io/airshipit/horizon:${BASE_TAG}
ARG OPENSTACK_RELEASE
ARG CONSTRAINTS=https://raw.githubusercontent.com/openstack/requirements/stable/${OPENSTACK_RELEASE}/upper-constraints.txt
ARG CONSTRAINTS_2024_1=https://opendev.org/openstack/requirements/raw/branch/unmaintained/2024.1/upper-constraints.txt

RUN pip install -c ${CONSTRAINTS} jaeger-client

RUN apt-get update && \
    apt-get install -y --no-install-recommends build-essential python3-dev git && \
    pip install -c ${CONSTRAINTS_2024_1} octavia-dashboard && \
    git clone -b stable/${OPENSTACK_RELEASE} \
        --single-branch https://git.openstack.org/openstack/cloudkitty-dashboard.git && \
    cd cloudkitty-dashboard && python setup.py install && cd .. && rm -rf cloudkitty-dashboard && \
    apt-get purge -y build-essential python3-dev && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

RUN pip install -c ${CONSTRAINTS} python-cloudkittyclient
RUN pip install -c ${CONSTRAINTS} masakari-dashboard
RUN pip install -c ${CONSTRAINTS} designate-dashboard
RUN pip install -c ${CONSTRAINTS} heat-dashboard
RUN pip install oslo.policy==4.3.0
