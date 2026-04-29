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
      version = "~> 1.3.0"
    }
  }
}

provider "libvirt" {
  uri = data.sops_file.secret_vars.data["libvirt_uri"]
}

provider "sops" {}
