# Custom images for Openstack

## Building all images for new Openstack release

(Optional) To disable timestamps use this

```bash
export USE_TIMESTAMP="false"
```

Executing this commands will build and push all Openstack images

```bash
export OPENSTACK_RELEASE="2025.1"
export TOOLS_VERSION="0.6" # increment this

bash build-local.sh
```

## Building specific images only

Use the `IMAGES` variable with a comma-separated list of image names:

```bash
export OPENSTACK_RELEASE="2025.1"
export IMAGES="nova,neutron"

bash build-local.sh
```

Available image names can be found in [images.yaml](images.yaml).
