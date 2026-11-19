# syntax=docker/dockerfile:1
ARG OPENSTACK_RELEASE=2026.1
ARG BASE_TAG=${OPENSTACK_RELEASE}-ubuntu_noble

FROM quay.io/airshipit/watcher:${BASE_TAG}
ARG OPENSTACK_RELEASE
RUN --mount=from=uv,source=/uv,target=/usr/local/bin/uv \
    --mount=from=overrides,target=/overrides \
    /overrides/apply.sh "$OPENSTACK_RELEASE"
