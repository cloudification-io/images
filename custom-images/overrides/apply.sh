#!/bin/sh
# Apply the Python pins of /overrides/<release>.txt to the image's Python environment.
#
# Picks the interpreter (airship venv, kolla venv, or the system Python) and hands
# over to apply.py, which runs under that interpreter. Called from a Dockerfile as
#   RUN --mount=from=uv,source=/uv,target=/usr/local/bin/uv \
#       --mount=from=overrides,target=/overrides \
#       /overrides/apply.sh "$OPENSTACK_RELEASE"
set -eu

release="${1:?usage: apply.sh <release>}"
dir="$(cd "$(dirname "$0")" && pwd)"

if [ -x /var/lib/openstack/bin/python ]; then
    exec /var/lib/openstack/bin/python "$dir/apply.py" "$dir/$release.txt"
elif [ -x /var/lib/kolla/venv/bin/python ]; then
    exec /var/lib/kolla/venv/bin/python "$dir/apply.py" "$dir/$release.txt"
else
    exec python3 "$dir/apply.py" --break-system-packages "$dir/$release.txt"
fi
