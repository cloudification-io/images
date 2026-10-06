#!/bin/bash
# Expand custom-images/images.yaml into build rows, one per (image, release).
#
# Prints a JSON array; each row has name, release, row_id, dockerfile, context,
# tag_prefix, base_image, paths. Paths are relative to custom-images/.
#
#   IMAGES=nova,keystone      only these image names (empty = all)
#   OPENSTACK_RELEASE=2026.1  only this release (empty = all; never matches release-less images)
set -euo pipefail

for tool in yq jq; do
    if ! command -v "$tool" &>/dev/null; then
        echo "ERROR: $tool is not installed (brew install $tool)" >&2
        exit 1
    fi
done

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IMAGES="${IMAGES:-}"
OPENSTACK_RELEASE="${OPENSTACK_RELEASE:-}"

ROWS=$(yq -o=json '.images' "$SCRIPT_DIR/images.yaml" | jq -c \
    --arg images "$IMAGES" \
    --arg release "$OPENSTACK_RELEASE" '
def subst($rel): gsub("\\{release\\}"; $rel);
def has_release_ph: test("\\{release\\}");
[ .[]
  | (.name // error("image without name")) as $name
  | ([.tag_template, .dockerfile, .context, (.base_image // "")] | map(has_release_ph) | any) as $needs
  | (.releases // []) as $rels
  | if ($rels | type) != "array" or ($rels | any(type != "string" or . == "")) then
      error("\($name): releases must be a list of non-empty quoted strings") else . end
  | if $needs and ($rels | length) == 0 then
      error("\($name): {release} placeholder used but releases is missing or empty") else . end
  | if ($needs | not) and ($rels | length) > 0 then
      error("\($name): releases given but no {release} placeholder") else . end
  | (if ($rels | length) == 0 then [""] else $rels end)[] as $rel
  | { name: $name, release: $rel,
      row_id: (if $rel == "" then $name else "\($name)-\($rel)" end),
      dockerfile: (.dockerfile | subst($rel)), context: (.context | subst($rel)),
      tag_prefix: (.tag_template | subst($rel)),
      base_image: ((.base_image // "") | subst($rel)),
      paths: (.paths // []) } ]
| (group_by(.row_id) | map(select(length > 1) | .[0].row_id)) as $dups
| if ($dups | length) > 0 then error("duplicate row ids: \($dups | join(", "))") else . end
| map(select($images == "" or (.name as $n | $images | split(",") | map(gsub("\\s";"")) | index($n) != null)))
| map(select($release == "" or .release == $release))
')

# image of the last FROM line, with a stage alias resolved to its FROM image
final_from_image() {
    awk '
        $1 == "FROM" {
            img = ""
            for (i = 2; i <= NF; i++) if ($i !~ /^--/) { img = $i; break }
            for (i = 2; i < NF; i++) if (toupper($i) == "AS") stage[$(i+1)] = img
            last = img
        }
        END { print (last in stage) ? stage[last] : last }
    ' "$1"
}

# base_image must be the final-stage FROM image of the row's Dockerfile
while IFS=$'\t' read -r row_id dockerfile base_image; do
    [[ -n "$base_image" ]] || continue
    if [[ ! -f "$SCRIPT_DIR/$dockerfile" ]]; then
        echo "ERROR: $row_id: dockerfile $dockerfile does not exist" >&2
        exit 1
    fi
    repo=${base_image%%:*}
    repo=${repo#docker.io/library/}
    repo=${repo#docker.io/}
    from_image=$(final_from_image "$SCRIPT_DIR/$dockerfile")
    if [[ "${from_image%%[:@]*}" != "$repo" ]]; then
        echo "ERROR: $row_id: base_image repository '$repo' is not the final FROM image ('$from_image') in $dockerfile" >&2
        exit 1
    fi
done < <(jq -r '.[] | [.row_id, .dockerfile, .base_image] | @tsv' <<<"$ROWS")

echo "$ROWS"
