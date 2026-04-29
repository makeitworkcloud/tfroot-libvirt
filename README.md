<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3 |
| <a name="requirement_libvirt"></a> [libvirt](#requirement\_libvirt) | ~> 0.9.0 |
| <a name="requirement_sops"></a> [sops](#requirement\_sops) | ~> 1.3.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_libvirt"></a> [libvirt](#provider\_libvirt) | ~> 0.9.0 |
| <a name="provider_sops"></a> [sops](#provider\_sops) | ~> 1.3.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_k3s"></a> [k3s](#module\_k3s) | git::https://github.com/makeitworkcloud/terraform-libvirt-domain.git | n/a |
| <a name="module_runner"></a> [runner](#module\_runner) | git::https://github.com/makeitworkcloud/terraform-libvirt-domain.git | n/a |

## Resources

| Name | Type |
|------|------|
| [libvirt_pool.cluster](https://registry.terraform.io/providers/dmacvicar/libvirt/latest/docs/resources/pool) | resource |
| [sops_file.secret_vars](https://registry.terraform.io/providers/carlpett/sops/latest/docs/data-sources/file) | data source |

## Inputs

No inputs.

## Outputs

No outputs.
<!-- END_TF_DOCS -->