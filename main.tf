data "sops_file" "secret_vars" {
  source_file = "${path.module}/secrets/secrets.yaml"
}

locals {
  # Boot images
  # Direct mirror that provides Content-Length header (required by libvirt provider)
  fedora_image_url = "https://dl.fedoraproject.org/pub/fedora/linux/releases/43/Cloud/x86_64/images/Fedora-Cloud-Base-Generic-43-1.6.x86_64.qcow2?v=3"

  # GitHub
  github_org = "makeitworkcloud"

  # ArgoCD bootstrap target (root of repo manages bootstrap + workloads)
  cluster_repo_url    = "https://github.com/makeitworkcloud/kustomize-cluster"
  cluster_repo_branch = "main"
  cluster_repo_path   = "."

  # k3s
  k3s_ip         = "192.168.102.2"
  k3s_version    = "v1.31.4+k3s1" # bump as needed; see https://github.com/k3s-io/k3s/releases
  argocd_version = "v2.13.2"      # bump as needed; see https://github.com/argoproj/argo-cd/releases
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
    ssh_authorized_key  = data.sops_file.secret_vars.data["ssh_admin_pubkey"]
    k3s_version         = local.k3s_version
    argocd_version      = local.argocd_version
    cluster_repo_url    = local.cluster_repo_url
    cluster_repo_branch = local.cluster_repo_branch
    cluster_repo_path   = local.cluster_repo_path
  }
  cloudinit_network_config_template = "${path.module}/cloud-init/network_config.cfg"
  cloudinit_network_config_vars     = { private_ip_addr = local.k3s_ip }
}
