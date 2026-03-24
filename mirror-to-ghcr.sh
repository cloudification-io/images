#!/bin/bash
set -euo pipefail

# Mirror upstream images locally using skopeo
#
# Prerequisites: skopeo, yq, jq
#   brew install skopeo yq jq
#   skopeo login ghcr.io
#
# Usage:
#   ./mirror-to-ghcr.sh                                    # mirror all
#   ./mirror-to-ghcr.sh --dry-run                          # preview only
#   ./mirror-to-ghcr.sh --images nova,horizon              # specific images
#   ./mirror-to-ghcr.sh --suffix -20260323                 # append suffix to kolla images
#   ./mirror-to-ghcr.sh --dry-run --suffix -20260323       # combine flags
#
# Environment overrides:
#   IMAGE_PREFIX   destination registry prefix  (default: ghcr.io/cloudification-io)
#   DRY_RUN        true/false                   (default: false)
#   IMAGES         comma-separated filter       (default: empty = all)
#   SUFFIX         suffix for kolla dest tags   (default: empty)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG="$SCRIPT_DIR/mirror-images.yaml"
IMAGE_PREFIX="${IMAGE_PREFIX:-ghcr.io/cloudification-io}"
DRY_RUN="${DRY_RUN:-false}"
IMAGES="${IMAGES:-}"
SUFFIX="${SUFFIX:-}"


while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)   DRY_RUN=true; shift ;;
        --images)    IMAGES="$2"; shift 2 ;;
        --suffix)    SUFFIX="$2"; shift 2 ;;
        --prefix)    IMAGE_PREFIX="$2"; shift 2 ;;
        -h|--help)
            sed -n '3,/^$/s/^# \?//p' "$0"
            exit 0
            ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done


for cmd in skopeo yq jq; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "ERROR: $cmd is not installed" >&2
        exit 1
    fi
done

MATRIX=$(yq -o=json '{
  "include": [.images[] | . as $img | .tags[] | {
    "name":       $img.name,
    "source":     $img.source,
    "tag":        .tag,
    "alias":      (.alias // ""),
    "suffix_tag": ($img.suffix_tag // false)
  }]
}' "$CONFIG")


if [[ -n "$IMAGES" ]]; then
    MATRIX=$(echo "$MATRIX" | jq -c --arg f "$IMAGES" '
      .include |= [.[] | select(
        .name as $n | ($f | split(",") | map(gsub("\\s";"")) | index($n)) != null
      )]')
fi

IMAGE_COUNT=$(echo "$MATRIX" | jq '.include | length')

if [[ "$IMAGE_COUNT" -eq 0 ]]; then
    echo "No images matched the filter."
    exit 0
fi


echo "Destination:  $IMAGE_PREFIX"
echo "Images:       $IMAGE_COUNT"
[[ -n "$IMAGES" ]]  && echo "Filter:       $IMAGES"
[[ -n "$SUFFIX" ]]  && echo "Suffix:       $SUFFIX"
[[ "$DRY_RUN" == "true" ]] && echo "*** DRY RUN ***"
echo ""


MIRRORED=()
FAILED=()

for row in $(echo "$MATRIX" | jq -r '.include[] | @base64'); do
    _jq() { echo "$row" | base64 --decode | jq -r "$1"; }

    name=$(_jq '.name')
    source=$(_jq '.source')
    tag=$(_jq '.tag')
    alias=$(_jq '.alias')
    suffix_tag=$(_jq '.suffix_tag')

    dst_tag="$tag"
    if [[ -n "$SUFFIX" && "$suffix_tag" == "true" ]]; then
        dst_tag="${tag}${SUFFIX}"
    fi

    src="docker://${source}:${tag}"
    dst="docker://${IMAGE_PREFIX}/${name}:${dst_tag}"

    echo "──── $name"
    echo "  src: ${source}:${tag}"
    echo "  dst: ${IMAGE_PREFIX}/${name}:${dst_tag}"

    if [[ "$DRY_RUN" == "true" ]]; then
        MIRRORED+=("${IMAGE_PREFIX}/${name}:${dst_tag}")
    else
        if skopeo copy --all --retry-times 3 "$src" "$dst"; then
            MIRRORED+=("${IMAGE_PREFIX}/${name}:${dst_tag}")
        else
            echo "  WARN: failed to copy" >&2
            FAILED+=("${source}:${tag}")
        fi
    fi


    if [[ -n "$alias" ]]; then
        dst_alias="docker://${IMAGE_PREFIX}/${name}:${alias}"
        echo "  alias: ${IMAGE_PREFIX}/${name}:${alias}"

        if [[ "$DRY_RUN" != "true" ]]; then
            if skopeo copy --all --retry-times 3 "$src" "$dst_alias"; then
                MIRRORED+=("${IMAGE_PREFIX}/${name}:${alias}")
            else
                echo "  WARN: failed to copy alias" >&2
                FAILED+=("${source}:${tag} (alias ${alias})")
            fi
        else
            MIRRORED+=("${IMAGE_PREFIX}/${name}:${alias}")
        fi
    fi
done


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
