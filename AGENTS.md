# Agent Instructions

OpenTofu root for the libvirt/KVM infrastructure that hosts the Make IT Work Cloud cluster and runner network.

Use GitHub MCP and PR CI plans as validation authority. Same-repository PRs can produce a credentialed plan; `main` is an environment-gated apply path. Do not run OpenTofu, Makefile, SSH, host-firewall, state, import, taint, repair, or apply operations from this server.

`README.md` is terraform-docs generated in replace mode; keep operational context here or in retrievable skills. The shared workflow and canonical runner configuration are owned by `shared-workflows` and `images/tfroot-runner`. Keep SOPS and SSH material encrypted and never expose state, credentials, private keys, or sensitive plans.

## Retained k3s storage

`module.k3s.existing_disks` attaches externally owned sparse raw files; this root must not create, resize, import, format, or delete them. Keep `vda` and the managed `vdb` data disk unchanged. The additional `vdc`/`vdd` files live outside `/mnt/nvme/cluster`, so replacing VM-owned images does not remove their backing files.

| Tier | Hero path | Maximum logical bytes | Guest mount | XFS UUID |
| --- | --- | ---: | --- | --- |
| SSD | `/mnt/ssd/persistent/k3s-pv-ssd.raw` | 1649267441664 (1.5 TiB) | `/srv/k3s/ssd` | `6bb8172e-7b83-4987-8eda-24b75c697860` |
| NVMe | `/mnt/nvme/persistent/k3s-pv-nvme.raw` | 429496729600 (400 GiB) | `/srv/k3s/nvme` | `028fc5ee-f25b-4b28-8619-2fbc78a0a3ae` |

These are intended identities, not evidence that the images or filesystems exist. Creation, attachment and first-time initialization require separate approval of exact targets and commands. Before creation, verify the host arrays are mounted, budget existing images at maximum growth, preserve host headroom, and refuse an existing destination. Provision without preallocation and keep host access restricted to the established QEMU identity. Never initialize by guessed `/dev/vdX`: verify the configured serial, expected capacity, absence of filesystem/partition signatures and exclusive ownership first. Never force-format a replacement attachment or regenerate these UUIDs during a rebuild.

Both UUID-based mount units are required by k3s. Missing mounts, wrong filesystem identities or mount removal intentionally prevent or stop the entire single-node k3s service. Cloud-init does not initialize these disks. Template updates prepare future bootstrap; they do not install mount units or service drop-ins in an existing VM. Existing `/dev/vdb` cloud-init formatting behavior is unchanged.

Before any apply, inspect the CI plan for unexpected boot/data volume changes or VM replacement. A 2026-10-27 metadata observation found live boot capacity 5 GiB versus the declared 20 GiB; do not reconcile that drift incidentally. Obtain a verified recovery copy and an approved execution path outside the affected VM before disruption: the MCP/control workloads run on this same node. Root merge/apply, module publication, manual live setup and replacement-VM recovery remain distinct gates.

After guest mounts are verified, `kustomize-cluster` owns StorageClass, static local PV and PVC declarations. Do not add them here, change existing claims, or infer data migration from new capacity. Retained local PVs need explicit node affinity and deliberate binding recovery after cluster recreation; `Retain` alone does not recover metadata or move data. Quiesced migration, isolated restore and application checks require separate approval and verification.

Sparse allocation is not reserved capacity. Monitor host free space, preserve sparsity in copies, and verify guest discard/TRIM reaches host hole punching before claiming reclamation. Never mount a guest-owned filesystem simultaneously on Hero and a VM; fence the old VM before replacement attachment. RAID and retained files do not provide host-loss backup.
