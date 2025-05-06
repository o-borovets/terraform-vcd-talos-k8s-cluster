terraform {
  required_version = ">=1.11.0"

  required_providers {
    talos = {
      source  = "siderolabs/talos"
      version = "0.7.1"
    }

    vcd = {
      source  = "vmware/vcd"
      version = "3.14.1"
    }
  }
}
