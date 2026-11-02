# syntax=docker/dockerfile:1
ARG OPENSTACK_RELEASE=2025.1
ARG BASE_TAG=${OPENSTACK_RELEASE}-ubuntu_noble

FROM quay.io/airshipit/cinder:${BASE_TAG} AS upstream

FROM quay.io/airshipit/venv_builder:${BASE_TAG} AS build
ENV PATH=/var/lib/openstack/bin:$PATH
ARG PYJWT_VERSION=2.14.0

# Replace the builder environment with the upstream service environment.
RUN rm -rf /var/lib/openstack
COPY --from=upstream /var/lib/openstack /var/lib/openstack

RUN sed -i "s/^PyJWT===.*/PyJWT===${PYJWT_VERSION}/" /upper-constraints.txt \
    && uv pip install \
         --python /var/lib/openstack/bin/python \
         -c /upper-constraints.txt \
         jaeger-client \
    && uv pip install \
         --python /var/lib/openstack/bin/python \
         --no-deps \
         -c /upper-constraints.txt \
         "PyJWT==${PYJWT_VERSION}" \
    && uv pip check --python /var/lib/openstack/bin/python

FROM quay.io/airshipit/cinder:${BASE_TAG}

# Avoid retaining files or metadata from the old PyJWT installation.
RUN rm -rf /var/lib/openstack
COPY --from=build --link /var/lib/openstack /var/lib/openstack
COPY --from=build /upper-constraints.txt /upper-constraints.txt
