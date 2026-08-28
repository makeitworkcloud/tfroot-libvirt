# k3s access and recovery

Normal kubectl access connects directly to `https://api.makeitwork.cloud` and
uses the Dex OIDC flow documented in the
[`kustomize-cluster` README](https://github.com/makeitworkcloud/kustomize-cluster#kubectl-access).
The k3s API server's matching OIDC issuer, client ID, and claim configuration is
provisioned from `cloud-init/k3s/cloud_init.cfg`.

The previous Cloudflare Access TCP route at `k3s.makeitwork.cloud` remains a
migration fallback until direct API discovery, watches, logs, exec, copy, and
port-forward are validated through the HTTPS endpoint.

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
ssh -A -J user@hero.makeitwork.cloud user@192.168.102.2
sudo KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl auth whoami
```

The expected identity is `system:admin` in `system:masters`.

### Required access and network checks

The VM's `user` account accepts the public key supplied as `ssh_admin_pubkey`
from the encrypted `secrets/secrets.yaml` inputs. The matching private key must
be loaded into the operator's SSH agent before connecting; the usual default
identity on `hero` is not sufficient. Confirm that the approved identity is
available locally, then forward it through `hero` with `-A`:

```bash
ssh-add -l
ssh -A -J user@hero.makeitwork.cloud user@192.168.102.2
```

The k3s VM has two interfaces. Use `192.168.102.2` on `nm-bridge` for
break-glass access; `192.168.122.0/24` is the libvirt `default` network and is
not the documented management path. If a VM replacement changes its SSH host
key, verify the replacement through the approved access handoff before updating
the cached key. Do not bypass host-key verification.

### Cloudflare tunnel recovery follow-up

The `ClusterTunnel` is configured with `newTunnel.name: cluster-apps-k3s`.
The cloudflare-operator creates this tunnel and does not adopt an existing
Cloudflare tunnel with the same name. A pre-existing tunnel causes Cloudflare
error 1013, prevents the operator from creating the `cluster-apps` ConfigMap,
and blocks every `TunnelBinding`, including the API and Argo CD routes.

When this happens, confirm the existing tunnel has no required connector or
route ownership, delete it with explicit approval, and let the operator create
the replacement. Then refresh and apply `tfroot-cloudflare` through its normal
PR workflow so the bootstrap `api` and `k3s` CNAMEs point at the replacement
tunnel ID. Verify the ClusterTunnel has a tunnel ID and cloudflared Deployment
before testing the public endpoints.

Keep `/etc/rancher/k3s/k3s.yaml` on the node. It contains cluster-admin client
credentials and must not be copied into this repository, chat, logs, or a
general-purpose workstation kubeconfig.
