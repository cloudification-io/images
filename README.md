# Custom images for Openstack

## Building all images for new Openstack release

(Optional) To disable timestamps use this

```bash
export USE_TIMESTAMP="false"
```

Executing this commands will build and push all Openstack images

```bash
export OPENSTACK_RELEASE="2025.1"
export TOOLS_VERSION="1.0" # increment this

bash custom-images/build-local.sh
```

## Building specific images only

Use the `IMAGES` variable with a comma-separated list of image names:

```bash
export OPENSTACK_RELEASE="2025.1"
export IMAGES="nova,neutron"

bash custom-images/build-local.sh
```

Available image names can be found in [images.yaml](custom-images/images.yaml).

## Mirroring images to Docker Hub

Mirror images from `ghcr.io/cloudification-io` to `docker.io/cloudification` using [skopeo](https://github.com/containers/skopeo). The script discovers packages dynamically via the GitHub API.

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

Preview what would be mirrored without actually copying:

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

Or only the latest timestamped tag per image:

```bash
MIRROR_MODE=latest-timestamped bash mirror-to-dockerhub.sh
```

### Excluding images

All discovered packages are mirrored by default. To exclude some:

```bash
EXCLUDE_IMAGES=coredns-k8s-gateway bash mirror-to-dockerhub.sh
```
