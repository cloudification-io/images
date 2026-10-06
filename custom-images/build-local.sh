#!/bin/bash
# Build (and push) the images defined in images.yaml, one build per (image, release).
#
#   IMAGES=nova,keystone      only these image names (empty = all)
#   OPENSTACK_RELEASE=2026.1  only this release (empty = all releases listed in images.yaml;
#                             never matches release-less images such as ceph)
#   REGISTRY_PREFIX=cloudification
#   USE_TIMESTAMP=true        append -YYYYmmddHHMMSS to the tag
#   PUSH_IMAGES=true
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REGISTRY_PREFIX="${REGISTRY_PREFIX:-cloudification}"
USE_TIMESTAMP="${USE_TIMESTAMP:-true}"
PUSH_IMAGES="${PUSH_IMAGES:-true}"

TIMESTAMP=""
if [[ "$USE_TIMESTAMP" == "true" ]]; then
    TIMESTAMP="-$(date -u +%Y%m%d%H%M%S)"
fi

# Platform detection for Apple Silicon
DOCKER_BUILD=(docker build)
if [[ $(uname -m) == 'arm64' ]]; then
    DOCKER_BUILD=(docker buildx build --platform linux/amd64)
fi

ROWS=$("$SCRIPT_DIR/matrix.sh")
BUILT_IMAGES=()

while IFS= read -r row; do
    name=$(jq -r '.name' <<<"$row")
    release=$(jq -r '.release' <<<"$row")
    dockerfile=$(jq -r '.dockerfile' <<<"$row")
    context=$(jq -r '.context' <<<"$row")
    tag_prefix=$(jq -r '.tag_prefix' <<<"$row")

    FULL_TAG="${REGISTRY_PREFIX}/${name}:${tag_prefix}${TIMESTAMP}"
    echo "======== Building: $(jq -r '.row_id' <<<"$row") → $FULL_TAG"

    build_args=()
    if [[ -n "$release" ]]; then
        build_args+=(--build-arg "OPENSTACK_RELEASE=$release")
    fi

    "${DOCKER_BUILD[@]}" \
        ${build_args[@]+"${build_args[@]}"} \
        -t "$FULL_TAG" \
        -f "$SCRIPT_DIR/$dockerfile" \
        "$SCRIPT_DIR/$context"

    if [[ "$PUSH_IMAGES" == "true" ]]; then
        docker push "$FULL_TAG"
    fi

    BUILT_IMAGES+=("$FULL_TAG")
done < <(jq -c '.[]' <<<"$ROWS")

echo ""
echo "Built images:"
if [[ ${#BUILT_IMAGES[@]} -gt 0 ]]; then
    printf '%s\n' "${BUILT_IMAGES[@]}"
fi
