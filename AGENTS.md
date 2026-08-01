# Agent Instructions

## Repository Purpose

OpenTofu root module for libvirt/KVM infrastructure.

## Git Workflow

Use a feature branch and open a pull request rather than pushing directly to
`main`. A push to `main` can invoke `apply` after tests pass and configured
environment gates approve it. Do not push any branch unless explicitly
requested.

## Pre-commit Configuration

Pre-commit configuration is centralized at
`https://raw.githubusercontent.com/makeitworkcloud/images/main/tfroot-runner/pre-commit-config.yaml`. The root
`.pre-commit-config.yaml` is generated and ignored; do not edit it.

For local development, run:
```bash
make test
```

This refreshes the generated config from the canonical source on every run and
replaces it only when the content changed.

### OpenTofu vs HashiCorp Terraform

The pre-commit-terraform hooks call `terraform` from PATH. In CI the
`tfroot-runner` image provides a `terraform` symlink pointing to `tofu`
(`terraform -> tofu`), so the call resolves to OpenTofu. This repository
standardizes on OpenTofu; use `tofu` for commands and validation rather than
assuming HashiCorp Terraform compatibility.

`make test` already exports `PCT_TFPATH=$(command -v tofu)` so the hooks
invoke OpenTofu. For `git commit`-triggered pre-commit runs, either:

- use direnv: `direnv allow` will source the repo's `.envrc`; or
- export it manually: `export PCT_TFPATH=$(command -v tofu)` in your shell.

## CI/CD

This repo uses the shared `opentofu.yml` workflow from `shared-workflows`, but with **custom configuration**:

- **Runner:** `arc-tf` (self-hosted, not `ubuntu-latest`)
- **Image:** the runner pod itself uses `ghcr.io/makeitworkcloud/tfroot-runner:latest`; there is no nested job container

The self-hosted runner is required because the workflow needs SSH access to the libvirt host, which is only reachable from the runner network.
The shared workflow fetches the canonical pre-commit config at runtime; this
repository does not provide a tracked copy.

## Local apply

`make init` / `make plan` / `make apply` need:

- `sops` available locally with AWS credentials authorized to use the KMS key in `.sops.yaml` (so `data.sops_file.secret_vars` decrypts)
- The makefile's `libvirt-ssh` target (auto-run by `init`) materializes the qemu+ssh keypair from sops into `.terraform/libvirt-ssh/` — no `~/.ssh/id_rsa` needed
- `tofu` on PATH, plus `direnv` (recommended) so `.envrc` exports `PCT_TFPATH` for pre-commit

### SSH-ing into the VMs

Both VMs are behind the libvirt host. The cloud-init user is `user`, not your local username:

```bash
ssh -J user@hero.makeitwork.cloud user@192.168.102.2   # k3s
ssh -J user@hero.makeitwork.cloud user@192.168.102.12  # runner
```

Use normal kubectl OIDC access whenever possible. See `KUBECTL.md` for the
Cloudflare/Dex access path and the node-local break-glass procedure. Never copy
the k3s admin kubeconfig off the VM.

### Host firewalld and the `libvirt` zone

VMs created here attach to the libvirt-managed `default` network, which uses
`virbr0` for NAT. firewalld assigns `virbr0` (and `virbr1..3`) to the
**`libvirt`** zone, **not** the host's `public` zone. The two zones have
independent rule sets:

- `public` zone (`enp7s0`, `nm-bridge`) governs traffic from the LAN to the
  host. Adding a port here lets LAN clients reach a host service.
- `libvirt` zone (`virbr0`, …) governs traffic from VM guests to the host.
  By default it allows only `dhcp dhcpv6 dns ssh tftp` and ends with a
  `priority=32767 reject` rich rule, so anything not in that allowlist is
  rejected rather than silently dropped.

This matters whenever WARP traffic terminates inside a VM and is then NATed
back out to a host service. The `warp-connector` cloudflared pod runs in the
`k3s` VM, so WARP-routed packets reach hero on `virbr0` from
`192.168.122.0/24`. They land in the `libvirt` zone — not `public` — and only
ports the `libvirt` zone admits will get a SYN-ACK. SSH (22) appears to "just
work" while every other host port is rejected over WARP. From the LAN the
same connection enters on `enp7s0` and hits `public`, masking the asymmetry.

Before changing the host firewall, collect the active zone and rule diagnostics
and obtain explicit confirmation for the proposed change. The libvirt provider
has no firewalld resource, so approved durable changes belong in retained host
configuration rather than this repository. `ansible-site-cluster` is archived
and must not be proposed as an active destination. If the underlying `default`
libvirt network is ever re-defined here as a `libvirt_network`, a reviewed plan
can set `<bridge zone="…"/>` on the XML to control which firewalld zone `virbr0`
lands in.

### Common apply hiccups

- **`Volume Upload Failed: unexpected EOF`** while creating boot disks — the ~700 MB Fedora qcow2 upload can be flaky, and boot-disk creation legitimately takes 5-7 minutes per VM. Inspect state, the host pool, and the next plan before retrying; proceed only after confirming the plan is limited to the expected recovery.
- **`Storage volume X exists already`** on a fresh apply — inspect the host pool and state to determine whether the volume is stale or owned elsewhere. Do not delete or import it without explicit confirmation and a reviewed recovery plan.
- **`Storage volume not found: no storage vol with matching path ...`** during refresh — compare state with the host pool, confirm whether recreation is intended, and review a state-repair plan before changing state.
- **Boot-disk filenames are a deterministic URL hash** (e.g. `k3s-94d57345.qcow2`). Changing `boot_image_url` plans replacement, but content changed behind an unchanged URL is not detected; diagnose that case and obtain confirmation for a reviewed, narrowly scoped replacement plan.
- **Cloud-init content replacement is automatic.** Changes to rendered metadata, user data, or network config trigger replacement of the cloud-init volume. Do not use blanket or multi-address taint commands.
- **Cluster + runner state survives boot-disk replacement.** `/var/lib/rancher` (k3s) and `/opt/actions-runner` are on persistent xfs `extra` volumes (`overwrite: false`). Cloud-init scripts are idempotent against this — see the `[ ! -f .runner ]` check in the runner template and the `kubectl get … || create` in the k3s template.
- **Pre-commit failures** — the canonical config may have changed. Re-run `make test` to refresh it and run the checks.

## Related Repositories

- `images` - Contains tfroot-runner image and canonical pre-commit config
- `shared-workflows` - Contains the reusable OpenTofu workflow
