# Coredns K8s gateway

This is patched version of CoreDNS with enabled plugins:
- k8s_gateway
- alternate

## How to build and push
```bash
docker build -f Dockerfile.v1.14.2 -t cloudification/coredns-k8s-gateway .
```
