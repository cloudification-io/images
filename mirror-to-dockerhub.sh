#!/bin/bash
set -euo pipefail

# Mirror container images from GHCR to Docker Hub using skopeo.
#
# Prerequisites: gh auth login, skopeo login ghcr.io, skopeo login docker.io
#
# Usage:
#   ./mirror-to-dockerhub.sh                              # mirror all tags (except coredns)
#   DRY_RUN=true ./mirror-to-dockerhub.sh                 # preview
#   IMAGES=nova,horizon ./mirror-to-dockerhub.sh           # specific images only
#   MIRROR_MODE=clean ./mirror-to-dockerhub.sh             # skip timestamped tags
#   EXCLUDE_IMAGES="" ./mirror-to-dockerhub.sh             # include coredns too

SOURCE_REGISTRY="${SOURCE_REGISTRY:-ghcr.io/cloudification-io}"
DEST_REGISTRY="${DEST_REGISTRY:-docker.io/cloudification}"
GH_ORG="${GH_ORG:-cloudification-io}"
IMAGES="${IMAGES:-}"
EXCLUDE_IMAGES="${EXCLUDE_IMAGES:-coredns-k8s-gateway}"
MIRROR_MODE="${MIRROR_MODE:-all}"
DRY_RUN="${DRY_RUN:-false}"

is_timestamp_tag() {
    [[ "$1" =~ -[0-9]{14}$ ]]
}

filter_tags() {
    local all_tags="$1"
    case "$MIRROR_MODE" in
        clean)
            while IFS= read -r tag; do
                [[ -n "$tag" ]] && ! is_timestamp_tag "$tag" && echo "$tag"
            done <<< "$all_tags"
            ;;
        latest-timestamped)
            while IFS= read -r tag; do
                [[ -n "$tag" ]] && is_timestamp_tag "$tag" && echo "$tag"
            done <<< "$all_tags" | sort | tail -1
            ;;
        all)
            while IFS= read -r tag; do
                [[ -n "$tag" ]] && echo "$tag"
            done <<< "$all_tags"
            ;;
        *)
            echo "ERROR: Unknown MIRROR_MODE: $MIRROR_MODE" >&2
            exit 1
            ;;
    esac
}

for cmd in gh skopeo; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "ERROR: $cmd is not installed" >&2
        exit 1
    fi
done

echo "Source:       $SOURCE_REGISTRY"
echo "Destination:  $DEST_REGISTRY"
echo "Mirror mode:  $MIRROR_MODE"
[[ -n "$IMAGES" ]] && echo "Include:      $IMAGES"
[[ -n "$EXCLUDE_IMAGES" ]] && echo "Exclude:      $EXCLUDE_IMAGES"
[[ "$DRY_RUN" == "true" ]] && echo "*** DRY RUN ***"
echo ""

PACKAGES=$(gh api --paginate \
    "orgs/${GH_ORG}/packages?package_type=container" \
    --jq '.[].name')

MIRRORED=()
FAILED=()

while IFS= read -r package; do
    [[ -z "$package" ]] && continue

    if [[ -n "$IMAGES" ]] && ! echo ",$IMAGES," | grep -q ",$package,"; then
        continue
    fi

    if [[ -n "$EXCLUDE_IMAGES" ]] && echo ",$EXCLUDE_IMAGES," | grep -q ",$package,"; then
        continue
    fi

    echo "======== $package"

    tags=$(gh api --paginate \
        "orgs/${GH_ORG}/packages/container/${package}/versions" \
        --jq '.[].metadata.container.tags[]' 2>/dev/null) || {
        echo "  WARN: failed to fetch versions, skipping" >&2
        continue
    }

    if [[ -z "$tags" ]]; then
        echo "  no tagged versions, skipping"
        continue
    fi

    filtered=$(filter_tags "$tags")

    if [[ -z "$filtered" ]]; then
        echo "  no tags after filtering, skipping"
        continue
    fi

    while IFS= read -r tag; do
        src="docker://${SOURCE_REGISTRY}/${package}:${tag}"
        dst="docker://${DEST_REGISTRY}/${package}:${tag}"

        if [[ "$DRY_RUN" == "true" ]]; then
            echo "  [dry-run] $src -> $dst"
            MIRRORED+=("${DEST_REGISTRY}/${package}:${tag}")
            continue
        fi

        echo "  $tag"
        if skopeo copy --all --retry-times 3 "$src" "$dst"; then
            MIRRORED+=("${DEST_REGISTRY}/${package}:${tag}")
        else
            echo "  WARN: failed to mirror $tag" >&2
            FAILED+=("${SOURCE_REGISTRY}/${package}:${tag}")
        fi
    done <<< "$filtered"
done <<< "$PACKAGES"

echo ""
echo "======== Summary ========"
if [[ "$DRY_RUN" == "true" ]]; then
    echo "Would mirror: ${#MIRRORED[@]} image(s)"
else
    echo "Mirrored: ${#MIRRORED[@]} image(s)"
fi
[[ ${#MIRRORED[@]} -gt 0 ]] && printf '  %s\n' "${MIRRORED[@]}"

if [[ ${#FAILED[@]} -gt 0 ]]; then
    echo "Failed:   ${#FAILED[@]}"
    printf '  %s\n' "${FAILED[@]}"
    exit 1
fi
