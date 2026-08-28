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
ssh -J user@hero.makeitwork.cloud user@192.168.102.2
sudo KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl auth whoami
```

The expected identity is `system:admin` in `system:masters`.

### Required access and network checks

The VM's `user` account accepts the public key supplied as `ssh_admin_pubkey`
from the encrypted `secrets/secrets.yaml` inputs. Approved Bitwarden users have
the matching private key made available to local OpenSSH by Bitwarden's SSH
agent; the key is not expected to exist as a workstation or `hero` filesystem
entry. Unlock Bitwarden and confirm that the local agent exposes the approved
identity before connecting:

```bash
ssh-add -l
ssh -J user@hero.makeitwork.cloud user@192.168.102.2
```

ProxyJump keeps destination authentication in the local SSH client, so this
path does not require agent forwarding. Do not add `-A` unless a separately
approved operation initiated from the k3s VM must use the forwarded agent.

The k3s VM has two interfaces. Use `192.168.102.2` on `nm-bridge` for
break-glass access; `192.168.122.0/24` is the libvirt `default` network and is
not the documented management path. If a VM replacement changes its SSH host
key, verify the replacement through the approved access handoff before updating
the cached key. Do not bypass host-key verification.

### Durable Cloudflare tunnel recovery

`tfroot-cloudflare` owns and protects the durable `cluster-apps-k3s` remote
tunnel identity plus the bootstrap `api` and `k3s` DNS records.
`kustomize-cluster` references that identity with
`ClusterTunnel/cluster-apps.spec.existingTunnel`; cloudflare-operator owns the
local cloudflared configuration and workload routes. A cluster or VM rebuild
must reacquire the same tunnel rather than delete or replace it.

During recovery:

1. Confirm the Terraform-managed remote tunnel and bootstrap DNS still exist.
   Repair them only through the reviewed `tfroot-cloudflare` PR and CI path.
2. Reconcile the SOPS-encrypted Cloudflare credentials and `ClusterTunnel`
   manifests from `kustomize-cluster`. Never extract or copy the tunnel
   credential JSON into this repository, chat, or an unencrypted file.
3. Verify `ClusterTunnel/cluster-apps` reports the Terraform-owned tunnel ID and
   name, and that its cloudflared Deployment is ready, before testing public
   endpoints.
4. Verify each `TunnelBinding` reports its expected hostname and Service target.
   cloudflare-operator owns workload CNAMEs and `_managed.<hostname>` TXT
   records; `api` and `k3s` remain Terraform-owned and must not have operator
   ownership TXT records.

If the operator reports `FailedReadingTxt`, inspect the exact workload record
and repair only stale operator-owned CNAME/TXT pairs with explicit approval.
Do not delete the durable tunnel or the Terraform-owned bootstrap DNS records.
A legacy `ClusterTunnel` created under the former `newTunnel` mode may also
retain `cfargotunnel.com/finalizer`; remove it only as reviewed one-time cleanup
after confirming the live resource uses `existingTunnel` and Terraform owns
the remote tunnel. Do not keep an explicit empty finalizer list in Git.

Keep `/etc/rancher/k3s/k3s.yaml` on the node. It contains cluster-admin client
credentials and must not be copied into this repository, chat, logs, or a
general-purpose workstation kubeconfig.
