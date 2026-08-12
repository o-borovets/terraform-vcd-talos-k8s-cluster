terraform {
  required_version = ">=1.11.0"

  required_providers {
    talos = {
      source  = "siderolabs/talos"
      version = "0.10.1"
    }

    vcd = {
      source  = "vmware/vcd"
      version = "3.14.1"
    }

    http = {
      source  = "hashicorp/http"
      version = "3.5.0"
    }

    external = {
      source  = "hashicorp/external"
      version = "2.3.5"
    }

    tls = {
      source  = "hashicorp/tls"
      version = "4.1.0"
    }
  }
}
