# Kubernetes API Load Balancer
locals {
  kube_api_load_balancer_private_ipv4 = cidrhost(tolist(vcd_nsxt_ip_set.load_balancer.ip_addresses)[0], -2)
  kube_api_load_balancer_public_ipv4  = null # var.kube_api_load_balancer_enabled ? hcloud_load_balancer.kube_api[0].ipv4 : null
  kube_api_load_balancer_public_ipv6  = null # var.kube_api_load_balancer_enabled ? hcloud_load_balancer.kube_api[0].ipv6 : null
  kube_api_load_balancer_name         = "${var.cluster_name}-kube-api"

  kube_api_load_balancer_public_network_enabled = coalesce(
    var.kube_api_load_balancer_public_network_enabled,
    var.cluster_access == "public"
  )
}

resource "vcd_nsxt_alb_pool" "kube_api" {
  count           = var.kube_api_load_balancer_enabled ? 1 : 0
  edge_gateway_id = data.vcd_nsxt_edgegateway.this.id

  name      = "${var.cluster_name}_kube_api"
  algorithm = "ROUND_ROBIN"

  member_group_id = vcd_nsxt_ip_set.control_plane.id

  passive_monitoring_enabled = true

  health_monitor {
    type = "PING"
  }
}

data "vcd_nsxt_alb_edgegateway_service_engine_group" "kube_api" {
  edge_gateway_id           = data.vcd_nsxt_edgegateway.this.id
  service_engine_group_name = data.vcd_nsxt_alb_edgegateway_service_engine_group.this.service_engine_group_name
}

resource "vcd_nsxt_alb_virtual_service" "kube_api" {
  count           = var.kube_api_load_balancer_enabled ? 1 : 0
  edge_gateway_id = data.vcd_nsxt_edgegateway.this.id

  name = "${var.cluster_name}_kube_api"

  virtual_ip_address = local.kube_api_load_balancer_private_ipv4

  service_engine_group_id = data.vcd_nsxt_alb_edgegateway_service_engine_group.kube_api.service_engine_group_id
  pool_id                 = vcd_nsxt_alb_pool.kube_api[0].id

  application_profile_type = "L4"

  service_port {
    start_port = local.kube_api_port
    type       = "TCP_PROXY"
  }

  service_port {
    start_port = local.talos_api_port
    type       = "TCP_PROXY"
  }
}
