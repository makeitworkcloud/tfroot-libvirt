# Agent Instructions

## Repository Purpose

OpenTofu root module for libvirt/KVM infrastructure.

## Push Access

Agents are authorized to push directly to `main` in this repository.

## Pre-commit Configuration

Pre-commit configuration is **centralized** in `makeitworkcloud/images/tfroot-runner/pre-commit-config.yaml`. The CI workflow fetches this config at runtime.

**Do not** create or modify `.pre-commit-config.yaml` in this repository.

For local development, run:
```bash
make test
```

This automatically fetches the canonical config if not present.

## CI/CD

This repo uses the shared `opentofu.yml` workflow from `shared-workflows`, but with **custom configuration**:

- **Runner:** `arc-dind` (self-hosted, not `ubuntu-latest`)
- **Container:** `image-registry.openshift-image-registry.svc:5000/public-registry/tfroot-runner:latest` (internal OpenShift registry, not GHCR)

This is required because the workflow needs SSH access to libvirt hosts, which is only available from the self-hosted runner network.

### Failure Modes

**"name unknown" or image pull failures:** The `tfroot-runner` image doesn't exist in the OpenShift internal registry. This happens when:

1. The `images` repo Build workflow failed (check for transient network errors, re-run if needed)
2. The `images` repo Pull workflow failed to import (the `|| true` masks failures - check logs for "Unable to connect" errors)

**To fix:** Re-run the Pull workflow in the `images` repo, or manually import:
```bash
oc import-image tfroot-runner:latest \
  --from=ghcr.io/makeitworkcloud/tfroot-runner:latest \
  -n public-registry \
  --confirm \
  --reference-policy=local
```

**Pre-commit failures:** If hooks fail unexpectedly, the canonical config may have changed. Delete `.pre-commit-config.yaml` locally and re-run `make test` to fetch the latest.

## Related Repositories

- `images` - Contains tfroot-runner image and canonical pre-commit config
- `shared-workflows` - Contains the reusable OpenTofu workflow and canonical pre-commit config
