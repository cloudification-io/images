#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OPENSTACK_RELEASE="${OPENSTACK_RELEASE:-2025.1}"
TOOLS_VERSION="${TOOLS_VERSION:-1.0}"
REGISTRY_PREFIX="${REGISTRY_PREFIX:-cloudification}"
USE_TIMESTAMP="${USE_TIMESTAMP:-true}"
PUSH_IMAGES="${PUSH_IMAGES:-true}"
IMAGES="${IMAGES:-}"

TIMESTAMP=""
if [[ "$USE_TIMESTAMP" == "true" ]]; then
    TIMESTAMP="-$(date -u +%Y%m%d%H%M%S)"
fi

# Platform detection for Apple Silicon
DOCKER_BUILD="docker build"
if [[ $(uname -m) == 'arm64' ]]; then
    DOCKER_BUILD="docker buildx build --platform linux/amd64"
fi

# Read image definitions from shared config (requires yq: brew install yq)
IMAGE_COUNT=$(yq '.images | length' "$SCRIPT_DIR/images.yaml")
BUILT_IMAGES=()

for ((i=0; i<IMAGE_COUNT; i++)); do
    name=$(yq ".images[$i].name" "$SCRIPT_DIR/images.yaml")
    dockerfile=$(yq ".images[$i].dockerfile" "$SCRIPT_DIR/images.yaml")
    context=$(yq ".images[$i].context" "$SCRIPT_DIR/images.yaml")
    tag_template=$(yq ".images[$i].tag_template" "$SCRIPT_DIR/images.yaml")

    # Substitute template placeholders
    tag_prefix=$(echo "$tag_template" | sed "s/{release}/$OPENSTACK_RELEASE/g; s/{tools_version}/$TOOLS_VERSION/g")

    # Filter if IMAGES is set
    if [[ -n "$IMAGES" ]] && ! echo ",$IMAGES," | grep -q ",$name,"; then
        continue
    fi

    FULL_TAG="${REGISTRY_PREFIX}/${name}:${tag_prefix}${TIMESTAMP}"
    echo "======== Building: $name → $FULL_TAG"

    $DOCKER_BUILD \
        --build-arg OPENSTACK_RELEASE="$OPENSTACK_RELEASE" \
        -t "$FULL_TAG" \
        -f "$SCRIPT_DIR/$dockerfile" \
        "$SCRIPT_DIR/$context"

    if [[ "$PUSH_IMAGES" == "true" ]]; then
        docker push "$FULL_TAG"
    fi

    BUILT_IMAGES+=("$FULL_TAG")
done

echo ""
echo "Built images:"
printf '%s\n' "${BUILT_IMAGES[@]}"
