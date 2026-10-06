# Custom images for Openstack

## Image definitions

[images.yaml](custom-images/images.yaml) lists every image with the OpenStack releases it is built for (`releases`) and its upstream base image (`base_image`). One image is built per (image, release) pair, so adding a release means appending it to the relevant `releases` lists. `custom-images/matrix.sh` expands the file into build rows and is used by both the local script and CI.

## Building images locally

Builds every listed release of every image and pushes the result:

```bash
bash custom-images/build-local.sh
```

The openstack-tools version is part of its `tag_template` in `images.yaml`; bump it there.

(Optional) To disable timestamps use this

```bash
export USE_TIMESTAMP="false"
```

## Building specific images or releases only

`IMAGES` takes a comma-separated list of image names, `OPENSTACK_RELEASE` a single release; both are filters, empty means all. A release filter never matches images without releases (openvswitch, sbom-discovery, ceph); build those by name.

```bash
export IMAGES="nova,neutron"
export OPENSTACK_RELEASE="2026.1"

bash custom-images/build-local.sh
```

## CI builds

[build-images.yml](.github/workflows/build-images.yml) builds and pushes to `ghcr.io/cloudification-io`:

- on push to `main`, the images whose files changed (every release of them; an `images.yaml` change rebuilds everything)
- weekly (Monday 03:00 UTC), the rows whose `base_image` digest differs from the one recorded on the last build (label `org.opencontainers.image.base.digest`); the job summary lists the decision per row
- on `workflow_dispatch`, with the same `images` and `openstack_release` filters as the local script; leave both empty to force a full rebuild

## Mirroring upstream images

[mirror-upstream.yml](.github/workflows/mirror-upstream.yml) copies the images in [mirror-images.yaml](mirror-images.yaml) from quay.io to `ghcr.io/cloudification-io` with `mirror-to-ghcr.sh`, on a push that changes the file and weekly (Monday 02:00 UTC). Kolla entries list their `releases` and use `{release}` in the tag. A tag is copied only when its upstream digest differs from the unsuffixed copy on GHCR, so unchanged images get no new dated tag; the `force` dispatch input (or `FORCE=true`) copies everything.

## Mirroring images to Docker Hub

Mirror images from `ghcr.io/cloudification-io` to `docker.io/cloudification` using [skopeo](https://github.com/containers/skopeo). The script mirrors the images listed in `IMAGES`, or discovers all packages via the GitHub API when `IMAGES` is unset.

In CI, the `mirror-to-dockerhub` job in [build-images.yml](.github/workflows/build-images.yml) runs the script after image builds, using the `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` repository secrets. Runs after `main` push and scheduled builds; a `workflow_dispatch` from any branch can preview the mirroring with the `mirror_dry_run` input.

### Prerequisites

```bash
gh auth login
skopeo login ghcr.io
skopeo login docker.io
```

### Mirror all images

```bash
bash mirror-to-dockerhub.sh
```

Preview what would be mirrored without actually copying. The preview compares manifest digests, so it needs the same registry logins as a real run:

```bash
DRY_RUN=true bash mirror-to-dockerhub.sh
```

### Mirror specific images

```bash
IMAGES=nova,horizon bash mirror-to-dockerhub.sh
```

### Mirror modes

By default all tags are mirrored (`MIRROR_MODE=all`). To mirror only clean (non-timestamped) tags:

```bash
MIRROR_MODE=clean bash mirror-to-dockerhub.sh
```

Or only the latest timestamped tag per tag prefix:

```bash
MIRROR_MODE=latest-timestamped bash mirror-to-dockerhub.sh
```

CI uses `MIRROR_MODE=recent`, the clean tags plus the latest timestamped tag per prefix, so a run does not re-inspect every historical tag:

```bash
MIRROR_MODE=recent bash mirror-to-dockerhub.sh
```

### Excluding images

All discovered packages are mirrored by default. To exclude some:

```bash
EXCLUDE_IMAGES=coredns-k8s-gateway bash mirror-to-dockerhub.sh
```
