#!/bin/bash
# Shared by mirror-to-ghcr.sh and mirror-to-dockerhub.sh (source it, do not run it).

# Index digest of a remote image. Absent tag or repository prints nothing;
# any other registry error is printed and returns 1.
get_manifest_digest() {
    local raw err rc=0
    err=$(mktemp)
    raw=$(skopeo inspect --raw --retry-times 3 "docker://$1" 2>"$err") || rc=$?
    if (( rc != 0 )) && grep -qiE 'manifest unknown|name unknown|not found|requested access to the resource is denied|authentication required' "$err"; then
        rm -f "$err"
        return 0
    fi
    cat "$err" >&2
    rm -f "$err"
    (( rc == 0 )) || return 1
    printf '%s' "$raw" | skopeo manifest-digest /dev/stdin
}

# Dated tags end in -YYYYmmddHHMMSS (custom builds) or -YYYYmmdd (upstream mirror copies).
is_timestamp_tag() {
    [[ "$1" =~ -[0-9]{14}$ || "$1" =~ -[0-9]{8}$ ]]
}

tag_prefix() {
    sed -E 's/-[0-9]{14}$//; s/-[0-9]{8}$//' <<< "$1"
}
