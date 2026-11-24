#!/bin/bash
# List the build rows that are new or changed between two commits.
#
# Prints a JSON array of row_ids: the rows of AFTER that BEFORE does not have, or has
# with different content. Rows only in BEFORE are not listed. Each commit's rows come
# from its own matrix.sh and images.yaml, without the IMAGES and OPENSTACK_RELEASE
# filters. Exits 1 when either matrix cannot be computed. Run inside the repository.
#
#   custom-images/changed-rows.sh BEFORE AFTER
set -euo pipefail

if [ $# -ne 2 ]; then
    echo "usage: $0 BEFORE AFTER" >&2
    exit 2
fi
BEFORE=$1
AFTER=$2

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

matrix_at() {
    local tree
    tree=$(mktemp -d "$TMP/tree.XXXXXX") || return
    git archive "$1" custom-images | tar -xf - -C "$tree" || return
    IMAGES='' OPENSTACK_RELEASE='' "$tree/custom-images/matrix.sh"
}

fail() {
    echo "ERROR: cannot compute the build matrix of $1" >&2
    exit 1
}

matrix_at "$BEFORE" > "$TMP/before.json" || fail "$BEFORE"
matrix_at "$AFTER" > "$TMP/after.json" || fail "$AFTER"

jq -c --slurpfile before "$TMP/before.json" '
    ($before[0] | INDEX(.row_id)) as $before_by_id
    | map(select(. != $before_by_id[.row_id]) | .row_id)
' "$TMP/after.json"
