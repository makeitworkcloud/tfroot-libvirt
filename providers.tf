terraform {
  required_version = ">= 1.3"

  backend "s3" {}

  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.9.0"
    }
    sops = {
      source  = "carlpett/sops"
      version = "~> 1.4.0"
    }
  }
}

locals {
  # SSH key + known_hosts are decrypted from sops by `make` and written under
  # .terraform/libvirt-ssh/ before tofu init. Keeping them out of the user's
  # ~/.ssh means local and CI both work without dev-key dependencies.
  libvirt_ssh_dir     = "${path.module}/.terraform/libvirt-ssh"
  libvirt_keyfile     = "${local.libvirt_ssh_dir}/id_ed25519"
  libvirt_known_hosts = "${local.libvirt_ssh_dir}/known_hosts"
}

provider "libvirt" {
  uri = "${data.sops_file.secret_vars.data["libvirt_uri"]}?sshauth=privkey&keyfile=${local.libvirt_keyfile}&knownhosts=${local.libvirt_known_hosts}"
}

provider "sops" {}
