locals {
  current_ip = concat(
    # local.firewall_use_current_ipv4 ? ["${chomp(data.http.current_ipv4[0].response_body)}/32"] : [],
    # local.firewall_use_current_ipv6 ? (
    #   strcontains(data.http.current_ipv6[0].response_body, ":") ?
    #   [cidrsubnet("${chomp(data.http.current_ipv6[0].response_body)}/64", 0, 0)] :
    #   []
    # ) : []
    []
  )

  network_public_ipv4_enabled = var.talos_public_ipv4_enabled

  # Network ranges
  network_ipv4_cidr   = var.network_ipv4_cidr
  node_ipv4_cidr      = coalesce(var.network_node_ipv4_cidr, cidrsubnet(local.network_ipv4_cidr, 3, 2))
  service_ipv4_cidr   = coalesce(var.network_service_ipv4_cidr, cidrsubnet(local.network_ipv4_cidr, 3, 3))
  pod_ipv4_cidr       = coalesce(var.network_pod_ipv4_cidr, cidrsubnet(local.network_ipv4_cidr, 1, 1))
  native_routing_cidr = coalesce(var.network_native_routing_cidr, local.network_ipv4_cidr)

  node_ipv4_cidr_skip_first_subnet = cidrhost(local.network_ipv4_cidr, 0) == cidrhost(local.node_ipv4_cidr, 0)
  network_ipv4_gateway             = cidrhost(local.network_ipv4_cidr, 1)

  # Subnet mask sizes
  network_pod_ipv4_subnet_mask_size = 24
  network_node_ipv4_subnet_mask_size = coalesce(
    var.network_node_ipv4_subnet_mask_size,
    32 - (local.network_pod_ipv4_subnet_mask_size - split("/", local.pod_ipv4_cidr)[1])
  )

  # Lists for control plane nodes
  control_plane_public_ipv4_list  = [] # [for server in vcd_vapp_vm.control_plane : server.ipv4_address]
  control_plane_private_ipv4_list = [for server in vcd_vapp_vm.control_plane : tolist(server.network)[0].ip]

  # Control plane VIPs
  control_plane_public_vip_ipv4  = null # local.control_plane_public_vip_ipv4_enabled ? data.hcloud_floating_ip.control_plane_ipv4[0].ip_address : null
  control_plane_private_vip_ipv4 = cidrhost(tolist(vcd_nsxt_ip_set.control_plane.ip_addresses)[0], -2)

  # Lists for worker nodes
  # worker_public_ipv4_list        = [for server in vcd_vapp_vm.worker : server.ipv4_address]
  worker_private_ipv4_list = [for server in vcd_vapp_vm.worker : tolist(server.network)[0].ip]
}

# Network Configuration
variable "network_ipv4_cidr" {
  type        = string
  default     = "10.0.0.0/16"
  description = "Specifies the main IPv4 CIDR block for the network. This CIDR block is used to allocate IP addresses within the network."
}

variable "network_node_ipv4_cidr" {
  type        = string
  default     = null # 10.0.64.0/19 when network_ipv4_cidr is 10.0.0.0/16
  description = "Specifies the Node CIDR used for allocating IP addresses to both Control Plane and Worker nodes within the cluster. If not explicitly provided, a default subnet is dynamically calculated from the specified network_ipv4_cidr."
}

variable "network_node_ipv4_subnet_mask_size" {
  type        = number
  default     = null # /25 when network_pod_ipv4_cidr is 10.0.128.0/17
  description = "Specifies the subnet mask size used for node pools within the cluster. This setting determines the network segmentation precision, with a smaller mask size allowing more IP addresses per subnet. If not explicitly provided, an optimal default size is dynamically calculated from the network_pod_ipv4_cidr."
}

variable "network_service_ipv4_cidr" {
  type        = string
  default     = null # 10.0.96.0/19 when network_ipv4_cidr is 10.0.0.0/16
  description = "Specifies the Service CIDR block used for allocating ClusterIPs to services within the cluster. If not provided, a default subnet is dynamically calculated from the specified network_ipv4_cidr."
}

variable "network_pod_ipv4_cidr" {
  type        = string
  default     = null # 10.0.128.0/17 when network_ipv4_cidr is 10.0.0.0/16
  description = "Defines the Pod CIDR block allocated for use by pods within the cluster. This CIDR block is essential for internal pod communications. If a specific subnet is not provided, a default is dynamically calculated from the network_ipv4_cidr."
}

variable "network_native_routing_cidr" {
  type        = string
  default     = null
  description = "Specifies the CIDR block that the CNI assumes will be routed natively by the underlying network infrastructure without the need for SNAT."
}

resource "vcd_network_routed_v2" "this" {
  name = "${var.cluster_name}_org_net"

  edge_gateway_id = data.vcd_nsxt_edgegateway.this.id

  gateway       = local.network_ipv4_gateway
  prefix_length = split("/", local.network_ipv4_cidr)[1]

  static_ip_pool {
    start_address = cidrhost(local.node_ipv4_cidr, 1)
    end_address   = cidrhost(local.node_ipv4_cidr, -1)
  }
}

data "vcd_nsxt_edgegateway" "this" {
  name = var.vcd_network.edge_gateway.name
}

data "vcd_nsxt_alb_edgegateway_service_engine_group" "this" {
  edge_gateway_id           = data.vcd_nsxt_edgegateway.this.id
  service_engine_group_name = var.vcd_network.edge_gateway.server_engine_group_name
}


resource "vcd_nsxt_ip_set" "control_plane" {
  edge_gateway_id = data.vcd_nsxt_edgegateway.this.id

  name = "${var.cluster_name}_control_plane_subnet"

  ip_addresses = [
    cidrsubnet(
      local.node_ipv4_cidr,
      local.network_node_ipv4_subnet_mask_size - split("/", local.node_ipv4_cidr)[1],
      0 + (local.node_ipv4_cidr_skip_first_subnet ? 1 : 0)
    ),
  ]
}

resource "vcd_nsxt_ip_set" "load_balancer" {
  edge_gateway_id = data.vcd_nsxt_edgegateway.this.id

  name = "${var.cluster_name}_load_balancer_subnet"

  ip_addresses = [
    cidrsubnet(
      local.node_ipv4_cidr,
      local.network_node_ipv4_subnet_mask_size - split("/", local.node_ipv4_cidr)[1],
      1 + (local.node_ipv4_cidr_skip_first_subnet ? 1 : 0)
    ),
  ]
}


resource "vcd_nsxt_ip_set" "worker" {
  for_each = { for np in local.worker_nodepools : np.name => np }

  edge_gateway_id = data.vcd_nsxt_edgegateway.this.id

  name = "${var.cluster_name}_${each.key}_worker_subnet"

  ip_addresses = [
    cidrsubnet(
      local.node_ipv4_cidr,
      local.network_node_ipv4_subnet_mask_size - split("/", local.node_ipv4_cidr)[1],
      2 + (local.node_ipv4_cidr_skip_first_subnet ? 1 : 0) + index(local.worker_nodepools, each.value)
    ),
  ]
}
