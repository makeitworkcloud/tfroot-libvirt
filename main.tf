data "sops_file" "secret_vars" {
  source_file = "${path.module}/secrets/secrets.yaml"
}

locals {
  # Boot images
  # Direct mirror that provides Content-Length header (required by libvirt provider)
  fedora_image_url = "https://dl.fedoraproject.org/pub/fedora/linux/releases/44/Cloud/x86_64/images/Fedora-Cloud-Base-Generic-44-1.7.x86_64.qcow2"

  # GitHub
  github_org = "makeitworkcloud"

  # ArgoCD bootstrap target — kustomize-cluster's bootstrap/ kustomization
  # contains the ArgoCD CR (consumed by argocd-operator) plus the operators-app
  # and workloads-app Applications that drive the rest of the sync.
  cluster_repo_url    = "https://github.com/makeitworkcloud/kustomize-cluster"
  cluster_repo_branch = "main"
  cluster_repo_path   = "bootstrap"

  # k3s
  k3s_ip      = "192.168.102.2"
  k3s_version = "v1.31.4+k3s1" # bump as needed; see https://github.com/k3s-io/k3s/releases

  # argocd-operator (community) — provides the argoproj.io/v1beta1 ArgoCD CRD
  # consumed by kustomize-cluster/bootstrap/argocd-config.yaml
  argocd_operator_version = "v0.14.0" # bump as needed; see https://github.com/argoproj-labs/argocd-operator/releases

  # cert-manager — required by argocd-operator's config/default to provision the
  # webhook-server-cert Secret. Installed during k3s bootstrap (before argocd-
  # operator) since argocd-operator can't come up without it, and the operator
  # is what brings ArgoCD up. The operators-app Application no longer manages
  # cert-manager itself, only the Issuer/ClusterIssuer resources downstream.
  cert_manager_version = "v1.20.2" # bump as needed; see https://github.com/cert-manager/cert-manager/releases
}

# Dedicated libvirt pool on /mnt/nvme RAID-1 for cluster volumes (keeps cluster IO off the root LV).
# One-time host setup required before first apply (hero has SELinux disabled, so no fcontext step):
#   ssh user@hero 'sudo mkdir -p /mnt/nvme/cluster'
resource "libvirt_pool" "cluster" {
  name = "cluster"
  type = "dir"

  target = {
    path = "/mnt/nvme/cluster"
  }
}

module "runner" {
  source         = "git::https://github.com/makeitworkcloud/terraform-libvirt-domain.git"
  name           = "runner"
  description    = "GitHub Actions self-hosted runner"
  memory         = 8192
  boot_image_url = local.fedora_image_url
  extra_volumes = [
    {
      name = "runner-var-lib-docker.qcow2"
      size = 107374182400 # 100 GiB
    },
    {
      name = "runner-opt-actions-runner.qcow2"
      size = 32212254720 # 30 GiB
    }
  ]
  cloudinit_meta_data_template = "${path.module}/cloud-init/meta_data.cfg"
  cloudinit_meta_data_vars     = { hostname = "runner" }
  cloudinit_user_data_template = "${path.module}/cloud-init/runner/cloud_init.cfg"
  cloudinit_user_data_vars = {
    ssh_authorized_key = data.sops_file.secret_vars.data["ssh_admin_pubkey"]
    github_org         = local.github_org
    github_token       = data.sops_file.secret_vars.data["github_token"]
  }
  cloudinit_network_config_template = "${path.module}/cloud-init/network_config.cfg"
  cloudinit_network_config_vars     = { private_ip_addr = data.sops_file.secret_vars.data["runner_ip_addr"] }
}

module "k3s" {
  source         = "git::https://github.com/makeitworkcloud/terraform-libvirt-domain.git"
  name           = "k3s"
  description    = "k3s single-node cluster"
  vcpu           = 6
  memory         = 16384
  storage_pool   = libvirt_pool.cluster.name
  boot_image_url = local.fedora_image_url
  extra_volumes = [
    {
      name = "k3s-var-lib-rancher.qcow2"
      size = 107374182400 # 100 GiB
    }
  ]
  cloudinit_meta_data_template = "${path.module}/cloud-init/meta_data.cfg"
  cloudinit_meta_data_vars     = { hostname = "k3s" }
  cloudinit_user_data_template = "${path.module}/cloud-init/k3s/cloud_init.cfg"
  cloudinit_user_data_vars = {
    ssh_authorized_key      = data.sops_file.secret_vars.data["ssh_admin_pubkey"]
    sops_age_key            = data.sops_file.secret_vars.data["sops_age_key"]
    k3s_version             = local.k3s_version
    cert_manager_version    = local.cert_manager_version
    argocd_operator_version = local.argocd_operator_version
    cluster_repo_url        = local.cluster_repo_url
    cluster_repo_branch     = local.cluster_repo_branch
    cluster_repo_path       = local.cluster_repo_path
  }
  cloudinit_network_config_template = "${path.module}/cloud-init/network_config.cfg"
  cloudinit_network_config_vars     = { private_ip_addr = local.k3s_ip }
}
