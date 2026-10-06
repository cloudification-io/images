#!/bin/bash
# Shared by mirror-to-ghcr.sh and mirror-to-dockerhub.sh (source it, do not run it).

# skopeo inspect with the given flags. Absent tag or repository prints nothing;
# any other registry error is printed and returns 1.
_inspect_or_absent() {
    local ref=$1; shift
    local out err rc=0
    err=$(mktemp)
    out=$(skopeo inspect --retry-times 3 "$@" "docker://$ref" 2>"$err") || rc=$?
    if (( rc != 0 )) && grep -qiE 'manifest unknown|name unknown|not found|requested access to the resource is denied|authentication required' "$err"; then
        rm -f "$err"
        return 0
    fi
    cat "$err" >&2
    rm -f "$err"
    (( rc == 0 )) || return 1
    printf '%s' "$out"
}

# Index digest of a remote image.
get_manifest_digest() {
    local raw
    raw=$(_inspect_or_absent "$1" --raw) || return 1
    [[ -n "$raw" ]] || return 0
    printf '%s' "$raw" | skopeo manifest-digest /dev/stdin
}

# Value of one config label of the linux/amd64 image; empty when the image or the label is absent.
get_image_label() {
    local out
    out=$(_inspect_or_absent "$1" --override-os linux --override-arch amd64) || return 1
    [[ -n "$out" ]] || return 0
    jq -r --arg l "$2" '.Labels[$l] // ""' <<< "$out"
}

# Dated tags end in -YYYYmmddHHMMSS (custom builds) or -YYYYmmdd (upstream mirror copies).
is_timestamp_tag() {
    [[ "$1" =~ -[0-9]{14}$ || "$1" =~ -[0-9]{8}$ ]]
}

tag_prefix() {
    sed -E 's/-[0-9]{14}$//; s/-[0-9]{8}$//' <<< "$1"
}
