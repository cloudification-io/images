# openstack-tools

## How to build container

```shell
export IMAGES="openstack-tools"

bash ../build-local.sh
```

Releases and the tools version (`tag_template`) are set in [images.yaml](../images.yaml); set `OPENSTACK_RELEASE` to build a single release. See the [top-level README](../../README.md).
