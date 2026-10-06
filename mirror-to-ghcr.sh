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
#   ./mirror-to-ghcr.sh --force                            # copy even when the digest is unchanged
#
# A tag is skipped when the upstream digest equals the digest of the unsuffixed
# destination tag, so repeated runs create no new suffixed tags for unchanged images.
#
# Environment overrides:
#   IMAGE_PREFIX   destination registry prefix  (default: ghcr.io/cloudification-io)
#   DRY_RUN        true/false                   (default: false)
#   IMAGES         comma-separated filter       (default: empty = all)
#   SUFFIX         suffix for kolla dest tags   (default: empty)
#   FORCE          true/false                   (default: false)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG="$SCRIPT_DIR/mirror-images.yaml"
IMAGE_PREFIX="${IMAGE_PREFIX:-ghcr.io/cloudification-io}"
DRY_RUN="${DRY_RUN:-false}"
IMAGES="${IMAGES:-}"
SUFFIX="${SUFFIX:-}"
FORCE="${FORCE:-false}"


while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)   DRY_RUN=true; shift ;;
        --images)    IMAGES="$2"; shift 2 ;;
        --suffix)    SUFFIX="$2"; shift 2 ;;
        --force)     FORCE=true; shift ;;
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

# shellcheck source=mirror-lib.sh
source "$SCRIPT_DIR/mirror-lib.sh"

MATRIX=$(yq -o=json '.images' "$CONFIG" | jq -c '
def has_release_ph: test("\\{release\\}");
{
  "include": [.[] | . as $img
    | ($img.name // error("image without name")) as $name
    | ($img.releases // []) as $rels
    | ([$img.tags[] | .tag, (.alias // "")] | map(has_release_ph) | any) as $needs
    | if ($rels | type) != "array" or ($rels | any(type != "string" or . == "")) then
        error("\($name): releases must be a list of non-empty quoted strings") else . end
    | if $needs and ($rels | length) == 0 then
        error("\($name): {release} placeholder used but releases is missing or empty") else . end
    | if ($needs | not) and ($rels | length) > 0 then
        error("\($name): releases given but no {release} placeholder") else . end
    | (if ($rels | length) == 0 then [""] else $rels end)[] as $rel
    | $img.tags[] | {
      "name":       $name,
      "source":     $img.source,
      "tag":        (.tag | gsub("\\{release\\}"; $rel)),
      "alias":      ((.alias // "") | gsub("\\{release\\}"; $rel)),
      "suffix_tag": ($img.suffix_tag // false)
    }]
}')


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
[[ "$FORCE" == "true" ]] && echo "Force:        copy unchanged images too"
[[ "$DRY_RUN" == "true" ]] && echo "*** DRY RUN ***"
echo ""


MIRRORED=()
SKIPPED=()
FAILED=()

for row in $(echo "$MATRIX" | jq -r '.include[] | @base64'); do
    _jq() { echo "$row" | base64 --decode | jq -r "$1"; }

    name=$(_jq '.name')
    source=$(_jq '.source')
    tag=$(_jq '.tag')
    alias=$(_jq '.alias')
    suffix_tag=$(_jq '.suffix_tag')

    src="docker://${source}:${tag}"

    echo "──── $name"
    echo "  src: ${source}:${tag}"

    if [[ "$FORCE" != "true" ]]; then
        if ! src_digest=$(get_manifest_digest "${source}:${tag}"); then
            echo "  WARN: cannot inspect ${source}:${tag}" >&2
            FAILED+=("${source}:${tag} (inspect)")
            continue
        fi
        if [[ -z "$src_digest" ]]; then
            echo "  WARN: upstream tag not found" >&2
            FAILED+=("${source}:${tag} (upstream missing)")
            continue
        fi
        if ! dst_digest=$(get_manifest_digest "${IMAGE_PREFIX}/${name}:${tag}"); then
            echo "  WARN: cannot inspect ${IMAGE_PREFIX}/${name}:${tag}" >&2
            FAILED+=("${IMAGE_PREFIX}/${name}:${tag} (inspect)")
            continue
        fi
        if [[ "$src_digest" == "$dst_digest" ]]; then
            echo "  up to date: ${IMAGE_PREFIX}/${name}:${tag} (${src_digest:7:12})"
            SKIPPED+=("${IMAGE_PREFIX}/${name}:${tag}")
            continue
        fi
    fi

    # The unsuffixed tag is the up-to-date marker, so it is written last and
    # only after the suffixed copy and the alias succeeded.
    targets=()
    if [[ -n "$SUFFIX" && "$suffix_tag" == "true" ]]; then
        targets+=("${tag}${SUFFIX}")
    fi
    if [[ -n "$alias" ]]; then
        targets+=("$alias")
    fi
    targets+=("$tag")

    for dst_tag in "${targets[@]}"; do
        dst="${IMAGE_PREFIX}/${name}:${dst_tag}"
        echo "  dst: $dst"
        if [[ "$DRY_RUN" == "true" ]]; then
            MIRRORED+=("$dst")
        elif skopeo copy --all --retry-times 3 "$src" "docker://$dst"; then
            MIRRORED+=("$dst")
        else
            echo "  WARN: failed to copy to $dst" >&2
            FAILED+=("${source}:${tag} -> ${dst_tag}")
            break
        fi
    done
done


echo ""
echo "======== Summary ========"
if [[ "$DRY_RUN" == "true" ]]; then
    echo "Would mirror: ${#MIRRORED[@]} image(s)"
else
    echo "Mirrored: ${#MIRRORED[@]} image(s)"
fi
[[ ${#MIRRORED[@]} -gt 0 ]] && printf '  %s\n' "${MIRRORED[@]}"
echo "Up to date: ${#SKIPPED[@]} image(s)"

if [[ ${#FAILED[@]} -gt 0 ]]; then
    echo "Failed:   ${#FAILED[@]}"
    printf '  %s\n' "${FAILED[@]}"
    exit 1
fi
