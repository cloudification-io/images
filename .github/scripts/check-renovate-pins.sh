#!/bin/bash
# Check that Renovate reads the first tag of every image in mirror-images.yaml.
#
#   check-renovate-pins.sh expected [mirror-images.yaml] | check-renovate-pins.sh check <renovate report>
#
# "expected" prints a "source tag" line for the first tag of every image without
# "suffix_tag" (needs yq). "check" reads those lines and fails for each one that is
# not in the report, and for each lookup Renovate could not do (needs jq only).
# The report is written by a Renovate run with RENOVATE_REPORT_TYPE=file.
set -euo pipefail

usage() {
    sed -n '4p' "$0" | sed 's/^# *//' >&2
    exit 2
}

case "${1:-}" in
expected)
    images_file="${2:-$(cd "$(dirname "$0")/../.." && pwd)/mirror-images.yaml}"
    yq -o=json '.images' "$images_file" |
        jq -r '.[] | select(.suffix_tag != true) | "\(.source) \(.tags[0].tag)"'
    ;;
check)
    report="${2:-}"
    [[ -n "$report" ]] || usage
    if [[ ! -f "$report" ]]; then
        echo "ERROR: $report not found" >&2
        exit 2
    fi
    expected=$(sort)
    if [[ -z "$expected" ]]; then
        echo "ERROR: no expected pins on stdin" >&2
        exit 2
    fi

    deps=$(jq -c '[.repositories[].packageFiles[][].deps[]]' "$report")
    extracted=$(jq -r '.[] | "\(.depName) \(if .currentDigest then "\(.currentDigest)-\(.depType)" else .currentValue end)"' <<<"$deps" | sort)
    failed=$(jq -r '.[]
        | (select(.skipReason) | "\(.depName): lookup skipped (\(.skipReason))"),
          ("\(.depName): \((.warnings // [])[].message)")' <<<"$deps")
    missing=$(comm -23 <(echo "$expected") <(echo "$extracted"))

    if [[ -n "$missing" ]]; then
        while read -r pin; do
            echo "$pin: first tag is not read by Renovate"
        done <<<"$missing"
        echo "README.md, section \"Renovate\", describes the layout Renovate can read." >&2
    fi
    if [[ -n "$failed" ]]; then
        echo "$failed"
    fi
    if [[ -n "$missing$failed" ]]; then
        exit 1
    fi

    echo "Renovate reads the first tag of all $(wc -l <<<"$expected" | tr -d ' ') tracked images."
    ;;
*)
    usage
    ;;
esac
