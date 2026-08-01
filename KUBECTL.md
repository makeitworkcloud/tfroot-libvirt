# k3s access and recovery

Normal kubectl access uses the Cloudflare Access TCP tunnel and Dex OIDC flow
documented in the
[`kustomize-cluster` README](https://github.com/makeitworkcloud/kustomize-cluster#kubectl-access).
The k3s API server's matching OIDC issuer, client ID, and claim configuration is
provisioned from `cloud-init/k3s/cloud_init.cfg`.

Cloud-init is the source of truth for new or replaced VMs, not a convergence
mechanism for an existing node. Changing the OIDC template does not update the
live file or restart k3s. A live migration must separately update
`/etc/rancher/k3s/config.yaml.d/oidc.yaml`, restart k3s, and verify a fresh OIDC
login. Those are confirmation-gated production operations.

## Break-glass access

This is not a self-service onboarding path. It is only for operators who
already have an approved `user` SSH identity and verified host keys for both
the libvirt host and k3s VM. If either is missing, stop and request an access
handoff; do not use trust-on-first-use, disable host-key checking, or extract
the SOPS-backed libvirt provider key for ad hoc shell access.

With that access already configured, connect through the libvirt host and use
the node-local admin kubeconfig:

```bash
ssh -J user@hero.makeitwork.cloud user@192.168.102.2
sudo KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl auth whoami
```

The expected identity is `system:admin` in `system:masters`.

Keep `/etc/rancher/k3s/k3s.yaml` on the node. It contains cluster-admin client
credentials and must not be copied into this repository, chat, logs, or a
general-purpose workstation kubeconfig.
