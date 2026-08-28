# Agent Instructions

OpenTofu root for the libvirt/KVM infrastructure that hosts the Make IT Work Cloud cluster and runner network.

Use GitHub MCP and PR CI plans as validation authority. Same-repository PRs can produce a credentialed plan; `main` is an environment-gated apply path. Do not run OpenTofu, Makefile, SSH, host-firewall, state, import, taint, repair, or apply operations from this server.

`README.md` is terraform-docs generated in replace mode; keep operational context here or in retrievable skills. The shared workflow and canonical runner configuration are owned by `shared-workflows` and `images/tfroot-runner`. Keep SOPS and SSH material encrypted and never expose state, credentials, private keys, or sensitive plans.
