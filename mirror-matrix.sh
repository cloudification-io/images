#!/bin/bash
# Expand mirror-images.yaml into rows, one per (image, tag, release).
#
# Prints a JSON array; each row has name, source, tag, alias, suffix_tag.
#
#   IMAGES=ovn,gnocchi-base   only these image names (empty = all)
set -euo pipefail

for tool in yq jq; do
    if ! command -v "$tool" &>/dev/null; then
        echo "ERROR: $tool is not installed (brew install $tool)" >&2
        exit 1
    fi
done

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IMAGES="${IMAGES:-}"

yq -o=json '.images' "$SCRIPT_DIR/mirror-images.yaml" | jq -c --arg images "$IMAGES" '
def has_release_ph: test("\\{release\\}");
[ .[] | . as $img
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
      name:       $name,
      source:     $img.source,
      tag:        (.tag | gsub("\\{release\\}"; $rel)),
      alias:      ((.alias // "") | gsub("\\{release\\}"; $rel)),
      suffix_tag: ($img.suffix_tag // false)
    } ]
| map(select($images == "" or (.name as $n | $images | split(",") | map(gsub("\\s";"")) | index($n) != null)))
'
