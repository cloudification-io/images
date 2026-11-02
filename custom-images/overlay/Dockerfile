# syntax=docker/dockerfile:1
# Upstream image plus the Python pin overrides and without the build toolchain.
# BASE_IMAGE comes from the row's base_image in images.yaml, RUN_USER from its build_args.
ARG BASE_IMAGE
FROM ${BASE_IMAGE}

ARG OPENSTACK_RELEASE
ARG RUN_USER=root
USER root

RUN --mount=from=uv,source=/uv,target=/usr/local/bin/uv \
    --mount=from=overrides,target=/overrides \
    /overrides/apply.sh "$OPENSTACK_RELEASE"

# linux-libc-dev pulls libc6-dev, build-essential, g++ and the *-dev packages with it
RUN if dpkg -s linux-libc-dev >/dev/null 2>&1; then \
        apt-get purge -y --auto-remove linux-libc-dev && rm -rf /var/lib/apt/lists/*; \
    fi

USER ${RUN_USER}
