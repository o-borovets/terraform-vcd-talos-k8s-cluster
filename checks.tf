check "kubeconfig_endpoint_mode_requirements" {
  assert {
    condition     = local.kubeconfig_endpoint_mode != "public_endpoint" || var.kube_api_hostname != null
    error_message = "kubeconfig_endpoint_mode=public_endpoint requires kube_api_hostname to be set."
  }

  assert {
    condition     = local.kubeconfig_endpoint_mode != "private_endpoint" || var.kube_api_private_hostname != null
    error_message = "kubeconfig_endpoint_mode=private_endpoint requires kube_api_private_hostname to be set."
  }

  assert {
    condition     = local.kubeconfig_endpoint_mode != "public_ip" || local.kube_api_public_ip != null
    error_message = "kubeconfig_endpoint_mode=public_ip requires a public Kubernetes API IP, such as a public VIP or a public load balancer."
  }
}

check "kubeconfig_endpoint_mode_ha_safety" {
  assert {
    condition = (
      length(local.control_plane_private_ipv4_list) == 1 ||
      local.kubeconfig_endpoint_mode != "public_ip" ||
      var.control_plane_public_vip_ipv4_enabled ||
      (var.kube_api_load_balancer_enabled && local.kube_api_load_balancer_public_network_enabled)
    )
    error_message = "For HA control planes, kubeconfig_endpoint_mode=public_ip requires a stable public Kubernetes API IP, such as a public VIP or public load balancer."
  }

  assert {
    condition = (
      length(local.control_plane_private_ipv4_list) == 1 ||
      local.kubeconfig_endpoint_mode != "private_ip" ||
      var.control_plane_private_vip_ipv4_enabled ||
      var.kube_api_load_balancer_enabled
    )
    error_message = "For HA control planes, kubeconfig_endpoint_mode=private_ip requires a stable private Kubernetes API IP, such as the private VIP or private load balancer."
  }
}

check "talosconfig_endpoints_mode_requirements" {
  assert {
    condition     = local.talosconfig_endpoints_mode != "public_ip" || length(local.control_plane_public_ipv4_list) > 0
    error_message = "talosconfig_endpoints_mode=public_ip requires public control plane IP addresses to be available."
  }
}
