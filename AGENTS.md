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

## Special Configuration

This repo uses `arc-dind` runner with an internal OpenShift registry image (`tfroot-runner`) because it requires SSH access to libvirt hosts.

## Related Repositories

- `images` - Contains tfroot-runner image and canonical pre-commit config
- `shared-workflows` - Contains the reusable OpenTofu workflow
