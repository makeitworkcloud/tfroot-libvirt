# Agent Instructions

OpenTofu root for the libvirt/KVM infrastructure that hosts the Make IT Work Cloud cluster and runner network.

Use PR CI plans as validation authority. Same-repository PRs can produce a credentialed plan; `main` is an environment-gated apply path. Do not directly access hosts, change host firewalls, or run state, import, taint, repair, or apply operations from an agent session. These operations belong to separately approved infrastructure or recovery procedures, not validation.

`README.md` is terraform-docs generated in replace mode; keep operational context here or in retrievable skills. The shared workflow and canonical runner configuration are owned by `shared-workflows` and `images/tfroot-runner`. Keep SOPS and SSH material encrypted and never expose state, credentials, private keys, or sensitive plans.
