terraform {
  required_version = ">= 1.3"

  backend "s3" {}

  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.9.0"
    }
    aap = {
      source  = "registry.terraform.io/ansible/aap"
      version = "~> 1.4.0"
    }
    sops = {
      source  = "carlpett/sops"
      version = "~> 1.3.0"
    }
  }
}

provider "libvirt" {
  uri = data.sops_file.secret_vars.data["libvirt_uri"]
}

provider "aap" {
  host     = data.sops_file.secret_vars.data["awx_controller"]
  username = data.sops_file.secret_vars.data["awx_username"]
  password = data.sops_file.secret_vars.data["awx_password"]
}

provider "sops" {}
