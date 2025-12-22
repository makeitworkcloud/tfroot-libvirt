data "sops_file" "secret_vars" {
  source_file = "${path.module}/secrets/secrets.yaml"
}

locals {
  # Use direct mirror that provides Content-Length header (required by libvirt provider)
  boot_image_url = "https://dl.fedoraproject.org/pub/fedora/linux/releases/42/Cloud/x86_64/images/Fedora-Cloud-Base-Generic-42-1.1.x86_64.qcow2"
}

module "runner" {
  source         = "git::https://github.com/makeitworkcloud/terraform-libvirt-domain.git"
  name           = "runner"
  description    = "GitHub Actions self-hosted runner"
  memory         = 8192
  boot_image_url = local.boot_image_url
  extra_volumes = [
    {
      name = "runner-var-lib-docker.qcow2"
      size = 107374182400
    }
  ]
  cloudinit_meta_data_template      = "${path.module}/cloud-init/meta_data.cfg"
  cloudinit_meta_data_vars          = { hostname = "runner" }
  cloudinit_user_data_template      = "${path.module}/cloud-init/runner/cloud_init.cfg"
  cloudinit_user_data_vars          = { ssh_authorized_key = data.sops_file.secret_vars.data["ssh_admin_pubkey"] }
  cloudinit_network_config_template = "${path.module}/cloud-init/network_config.cfg"
  cloudinit_network_config_vars     = { private_ip_addr = data.sops_file.secret_vars.data["runner_ip_addr"] }
  private_ip_addr                   = data.sops_file.secret_vars.data["runner_ip_addr"]
  proxyhost                         = data.sops_file.secret_vars.data["proxyhost"]
  enable_aap                        = true
  aap_inventory_name                = "libvirt"
}


