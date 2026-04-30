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
- **Container:** `ghcr.io/makeitworkcloud/tfroot-runner:latest`

The self-hosted runner is required because the workflow needs SSH access to the libvirt host, which is only reachable from the runner network.

## Local apply

`make init` / `make plan` / `make apply` need:

- `sops` available locally with the team's age key (so `data.sops_file.secret_vars` decrypts)
- The makefile's `libvirt-ssh` target (auto-run by `init`) materializes the qemu+ssh keypair from sops into `.terraform/libvirt-ssh/` — no `~/.ssh/id_rsa` needed
- `tofu` on PATH, plus `direnv` (recommended) so `.envrc` exports `PCT_TFPATH` for pre-commit

### SSH-ing into the VMs

Both VMs are behind the libvirt host. The cloud-init user is `user`, not your local username:

```bash
ssh -J user@hero.makeitwork.cloud user@192.168.102.2   # k3s
ssh -J user@hero.makeitwork.cloud user@192.168.102.12  # runner
```

### Common apply hiccups

- **`Volume Upload Failed: unexpected EOF`** while creating boot disks — flaky upload of the ~700 MB Fedora qcow2. Just re-run `make apply`; partial volumes get cleaned up automatically on retry. Boot-disk creation legitimately takes 5–7 minutes per VM.
- **`Storage volume X exists already`** on a fresh apply — host has stale volumes (e.g. from a previous failed apply). Delete via `ssh user@hero "sudo virsh -c qemu:///system vol-delete --pool <pool> <volname>"`. `sudo` is required. Run `pool-refresh <pool>` after.
- **`Storage volume not found: no storage vol with matching path …`** during refresh — state references a volume that was deleted out-of-band. `tofu state rm <addr>` and re-apply to recreate.
- **Boot-disk filenames are a deterministic URL hash** (e.g. `k3s-94d57345.qcow2`). Tofu won't recreate them when the boot image content changes server-side or when cloud-init templates change. Force a rebuild with `tofu taint module.<vm>.libvirt_volume.boot module.<vm>.libvirt_volume.cloudinit module.<vm>.libvirt_cloudinit_disk.commoninit`.
- **Cluster + runner state survives boot-disk replacement.** `/var/lib/rancher` (k3s) and `/opt/actions-runner` are on persistent xfs `extra` volumes (`overwrite: false`). Cloud-init scripts are idempotent against this — see the `[ ! -f .runner ]` check in the runner template and the `kubectl get … || create` in the k3s template.
- **Pre-commit failures** — the canonical config may have changed. `rm .pre-commit-config.yaml && make test` fetches the latest.

## Related Repositories

- `images` - Contains tfroot-runner image and canonical pre-commit config
- `shared-workflows` - Contains the reusable OpenTofu workflow and canonical pre-commit config
