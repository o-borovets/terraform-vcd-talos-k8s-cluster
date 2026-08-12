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

# Ingress Load Balancer
#
# Fronts the ingress controller's NodePorts on a public VIP. Separate from the
# Kubernetes API load balancer above in three ways that matter:
#
#   * the VIP is public and must be supplied (var.ingress_load_balancer_vip);
#     it cannot be derived from the node subnet the way the kube-api VIP is.
#   * members are the worker node IPs explicitly, NOT a member_group_id. The
#     kube-api pool uses an ip_set, and the consequence is visible in VCD: the
#     /25 gets expanded into 128 pool members of which a handful are up, so the
#     pool never reports UP and the health monitor is doing all the work. For an
#     ingress path that is the difference between "7 members, 7 up, UP" and
#     "128 members, 7 up, RUNNING". Explicit members track Terraform-managed
#     workers exactly, and are reconciled by the same apply that adds or removes
#     a node.
#   * an active TCP health monitor on the NodePort, because the alternative is
#     relying on passive monitoring alone -- which reacts only after client
#     connections have already failed. zeta ran that way and lost roughly half
#     its ingress capacity on every node reboot until 2026-08-12.
locals {
  ingress_load_balancer_enabled = var.ingress_load_balancer_enabled && var.ingress_load_balancer_vip != null
  ingress_load_balancer_ports   = local.ingress_load_balancer_enabled ? var.ingress_load_balancer_ports : {}
}

resource "vcd_nsxt_alb_pool" "ingress" {
  for_each = local.ingress_load_balancer_ports

  edge_gateway_id = data.vcd_nsxt_edgegateway.this.id

  name         = "${var.cluster_name}_worker_${each.value.node_port}"
  algorithm    = "LEAST_CONNECTIONS"
  default_port = each.value.node_port

  # One second of grace for in-flight requests when a member is deliberately
  # disabled. It does nothing for a node that has already died.
  graceful_timeout_period = 1

  # Both kinds of monitoring, deliberately. Passive reacts within about one
  # failed client connection but only sees live traffic; active catches a member
  # that is receiving none, and drives recovery back to UP after a reboot.
  passive_monitoring_enabled = true

  health_monitor {
    type = "TCP"
  }

  dynamic "member" {
    for_each = local.worker_private_ipv4_list
    content {
      ip_address = member.value
      port       = each.value.node_port
      ratio      = 1
      enabled    = true
    }
  }
}

resource "vcd_nsxt_alb_virtual_service" "ingress" {
  for_each = local.ingress_load_balancer_ports

  edge_gateway_id = data.vcd_nsxt_edgegateway.this.id

  name = "${var.cluster_name}_ingress_${each.key}"

  virtual_ip_address = var.ingress_load_balancer_vip

  service_engine_group_id = data.vcd_nsxt_alb_edgegateway_service_engine_group.kube_api.service_engine_group_id
  pool_id                 = vcd_nsxt_alb_pool.ingress[each.key].id

  # L4, not L7. The ingress controller runs with --enable-ssl-passthrough, so
  # TLS must reach it intact; an HTTPS application profile would terminate at
  # the ALB and break passthrough silently.
  application_profile_type = "L4"

  service_port {
    start_port = each.value.external_port
    end_port   = each.value.external_port
    type       = "TCP_PROXY"
  }
}
