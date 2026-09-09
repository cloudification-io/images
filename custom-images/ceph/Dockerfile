ARG CEPH_VERSION=v19.2.2
ARG BUILD_DATE

# Stage 0 — name the ceph image as a stage so ARG works in COPY --from
FROM quay.io/ceph/ceph:${CEPH_VERSION} AS ceph-base

# Stage 1 — patch the MGR python files using patch command
FROM debian:bookworm-slim AS patcher

RUN apt-get update && apt-get install -y patch && rm -rf /var/lib/apt/lists/*

# Copy original files from named ceph stage
COPY --from=ceph-base \
    /usr/share/ceph/mgr/rook/rook_cluster.py /tmp/rook_cluster.py
COPY --from=ceph-base \
    /usr/share/ceph/mgr/nfs/cluster.py /tmp/cluster.py

# Copy patch files
COPY 0001-mgr-rook-fix-get_hosts-InternalIP.patch /tmp/
COPY 0002-mgr-nfs-fix-cluster-info-rook.patch /tmp/

# Apply patches
RUN patch /tmp/rook_cluster.py \
      /tmp/0001-mgr-rook-fix-get_hosts-InternalIP.patch && \
    patch /tmp/cluster.py \
      /tmp/0002-mgr-nfs-fix-cluster-info-rook.patch && \
    echo "All patches applied"

# Stage 2 — final image
FROM ceph-base

COPY --from=patcher /tmp/rook_cluster.py \
    /usr/share/ceph/mgr/rook/rook_cluster.py
COPY --from=patcher /tmp/cluster.py \
    /usr/share/ceph/mgr/nfs/cluster.py
