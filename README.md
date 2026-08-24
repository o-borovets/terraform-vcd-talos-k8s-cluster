# Talos Kubernetes Cluster on VCD (VMware Cloud Director)

This Terraform module provisions a Talos-based Kubernetes cluster on a VMware Cloud Director (VCD) environment.

## Features

- Support for multiple control plane and worker node pools

## Usage

```hcl
module "vcd-cluster" {
  source = "github.com/o-borovets/vcd-talos-k8s-cluster"

  cluster_name   = "zeta"
  cluster_access = "private"

  network_ipv4_cidr = "10.1.0.0/16"

  vcd_org_name = "<your_org_name>"

  vcd_network = {
    edge_gateway = {
      name                      = "<edge_gateway_name>"
      server_engine_group_name  = "<server_engine_group_name>"
    }
  }

  control_plane_nodepools = [
    { name = "control-plane", type = "<sizing_policy_name>", count = 3 }
  ]

  worker_nodepools = [
    { name = "worker", type = "<sizing_policy_name>", count = 1 }
  ]
}
```
> **Note**: Replace placeholder values (<...>) with actual VCD configuration values.

<!-- Advanced Configuration -->
## :hammer_and_pick: Advanced Configuration

<!-- Cluster Access -->
<details>
<summary><b>Using with VCD CSI</b></summary>

When using the [cloud-director-named-disk-csi-driver](https://github.com/vmware/cloud-director-named-disk-csi-driver) it’s **mandatory** to set the `disk.enableUUID` virtual machine configuration option to enable disk detection by a node CSI driver.

#### Example

```hcl
module "vcd-cluster" {
  worker_nodepools = [
    {
      extra_parameters = [
        { key = "disk.enableUUID", value = "1" }
      ]
    }
  ]
}
```

</details>


<details>
<summary><b>Pinning the Talos boot image</b></summary>

The module downloads the Talos VMware OVA from the image factory and uploads it as a
catalog item named `talos-<version>-<fingerprint>`, where the fingerprint is derived from
the schematic id, the Talos version, the platform and the architecture. The catalog item is
replaced, not renamed, whenever that fingerprint changes.

This matters because `vcd_catalog_item.name` is not `ForceNew`, and the provider's update
path only writes the new name onto the vApp template that is already in the catalog — it
never re-uploads the OVA. A catalog item keyed on a bare version string can therefore hold
any image at all while `terraform plan` reports no changes.

The image factory serves no checksum on the free tier, so the module cannot verify the
download against upstream on its own. It always checks that the file is a real OVA — large
enough, and a tar whose first member is the `.ovf` descriptor — which is what catches the
HTML redirect page that a download without `--location` produces. To assert the exact bytes
as well, pin them:

```hcl
module "vcd-cluster" {
  talos_version    = "v1.13.8"
  talos_ova_sha256 = "984843fad655d9284820fb7890f640accb44de73a9c1bbc3e707b8be218eab11"
}
```

Setting or changing `talos_ova_sha256` forces one re-download and one re-upload. Each
verified download leaves a `<ova>.sha256` sidecar next to the OVA in the root module
directory, which is where the value to pin comes from.

</details>

## Roadmap
- [] Setup Renovate for dependency updates
- [] Support cluster creation without an existing edge gateway
- [] Implement firewall configuration
- [] Allow choice VM parameters without sizing policy
- [] Improve subnet management
- [] Add support for public networking
- [] Enable IPv6 support
- [] Pre-install optional Kubernetes components:
  - [] CNI (Container Network Interface)
  - [] CSI (Container Storage Interface)
  - [] CCM (Cloud Controller Manager)
  - [] Other useful addons
