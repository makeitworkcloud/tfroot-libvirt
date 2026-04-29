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

### OpenTofu vs HashiCorp Terraform

The pre-commit-terraform hooks call `terraform` from PATH. In CI the
`tfroot-runner` image symlinks `tofu → terraform` so the call resolves to
OpenTofu. Locally most developers have HashiCorp `terraform` from Homebrew,
which rejects tofu-only backend attributes (e.g. `assume_role_duration_seconds`).

`make test` already exports `PCT_TFPATH=$(command -v tofu)` so the hooks
invoke OpenTofu. For `git commit`-triggered pre-commit runs, either:

- use direnv: `direnv allow` will source the repo's `.envrc`; or
- export it manually: `export PCT_TFPATH=$(command -v tofu)` in your shell.

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
