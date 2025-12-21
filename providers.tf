terraform {
  required_version = ">= 1.3"

  backend "s3" {}

  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = ">= 0.8.2"
    }
    aap = {
      source  = "ansible/aap"
      version = ">= 1.3.0"
    }
    sops = {
      source  = "carlpett/sops"
      version = ">= 0.7.0"
    }
  }
}

provider "libvirt" {
  uri = data.sops_file.secret_vars.data["libvirt_uri"]
}

provider "aap" {
  host     = data.sops_file.secret_vars.data["aap_controller"]
  username = data.sops_file.secret_vars.data["aap_username"]
  password = data.sops_file.secret_vars.data["aap_password"]
}

provider "sops" {}
