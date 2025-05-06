# Talos Kubernetes Cluster on VCD (VMware Cloud Director)

This Terraform module provisions a Talos-based Kubernetes cluster on a VMware Cloud Director (VCD) environment.

## Features

- Support for multiple control plane and worker node pools

## Usage

```hcl
module "zeta-vcd-cluster" {
  source = "../../../../terraform/modules/vdc-talos"

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
> **Note**: Replace placeholder values (<...>) with actual VCD configuration values.

## Roadmap
- [] Setup Renovate for dependency updates
- [] Support cluster creation without an existing edge gateway
- [] Implement firewall configuration
- [] Improve subnet management
- [] Add support for public networking
- [] Enable IPv6 support
- [] Pre-install optional Kubernetes components:
  - [] CNI (Container Network Interface)
  - [] CSI (Container Storage Interface)
  - [] CCM (Cloud Controller Manager)
  - [] Other useful addons
