locals {
  # Talos Version
  talos_version_parts = regex("^v?(?P<major>[0-9]+)\\.(?P<minor>[0-9]+)\\.(?P<patch>[0-9]+)", var.talos_version)
  talos_version_major = local.talos_version_parts.major
  talos_version_minor = local.talos_version_parts.minor
  talos_version_patch = local.talos_version_parts.patch

  # Talos Nodes
  talos_primary_node_name         = sort(keys(vcd_vapp_vm.control_plane))[0]
  talos_primary_node_private_ipv4 = tolist(vcd_vapp_vm.control_plane[local.talos_primary_node_name].network)[0].ip
  talos_primary_node_public_ipv4  = try(local.control_plane_public_ipv4_list[0], null)
  # talos_primary_node_public_ipv6  = vcd_vapp_vm.control_plane[local.talos_primary_node_name].ipv6_address

  # Talos API
  talos_api_port = 50000
  talosconfig_endpoints_mode = (
    var.talosconfig_endpoints_mode == "auto" ?
    (var.cluster_access == "public" && length(local.control_plane_public_ipv4_list) > 0 ? "public_ip" : "private_ip") :
    var.talosconfig_endpoints_mode
  )
  talosconfig_endpoints = (
    local.talosconfig_endpoints_mode == "public_ip" ?
    local.control_plane_public_ipv4_list :
    local.control_plane_private_ipv4_list
  )
  talos_transport_primary_endpoint = (
    var.cluster_access == "public" && local.talos_primary_node_public_ipv4 != null ?
    local.talos_primary_node_public_ipv4 :
    local.talos_primary_node_private_ipv4
  )
  talos_transport_endpoints = (
    var.cluster_access == "public" && length(local.control_plane_public_ipv4_list) > 0 ?
    local.control_plane_public_ipv4_list :
    local.control_plane_private_ipv4_list
  )

  # Kubernetes API
  kube_api_private_ipv4 = (
    var.kube_api_load_balancer_enabled ? local.kube_api_load_balancer_private_ipv4 :
    var.control_plane_private_vip_ipv4_enabled ? local.control_plane_private_vip_ipv4 :
    local.talos_primary_node_private_ipv4
  )
  kube_api_private_host = coalesce(var.kube_api_private_hostname, local.kube_api_private_ipv4)
  kube_api_public_ip = (
    var.kube_api_load_balancer_enabled && local.kube_api_load_balancer_public_network_enabled && local.kube_api_load_balancer_public_ipv4 != null ? local.kube_api_load_balancer_public_ipv4 :
    var.control_plane_public_vip_ipv4_enabled ? local.control_plane_public_vip_ipv4 :
    local.talos_primary_node_public_ipv4
  )

  kube_api_port = 6443
  kubeconfig_endpoint_mode = (
    var.kubeconfig_endpoint_mode == "auto" ? (
      var.cluster_access == "private" ? (
        var.kube_api_private_hostname != null ? "private_endpoint" : "private_ip"
        ) : (
        var.kube_api_hostname != null ? "public_endpoint" :
        local.kube_api_public_ip != null ? "public_ip" :
        var.kube_api_private_hostname != null ? "private_endpoint" :
        "private_ip"
      )
    ) : var.kubeconfig_endpoint_mode
  )
  kubeconfig_host = (
    local.kubeconfig_endpoint_mode == "private_ip" ? local.kube_api_private_ipv4 :
    local.kubeconfig_endpoint_mode == "public_ip" ? local.kube_api_public_ip :
    local.kubeconfig_endpoint_mode == "public_endpoint" ? var.kube_api_hostname :
    local.kubeconfig_endpoint_mode == "private_endpoint" ? var.kube_api_private_hostname :
    local.kube_api_private_ipv4
  )
  kube_api_transport_host = (
    var.cluster_access == "private" ? local.kube_api_private_host :
    coalesce(var.kube_api_hostname, local.kube_api_public_ip, local.kube_api_private_host)
  )

  kube_api_url_internal  = "https://${local.kube_api_private_host}:${local.kube_api_port}"
  kube_api_url_transport = "https://${local.kube_api_transport_host}:${local.kube_api_port}"
  kubeconfig_url         = "https://${local.kubeconfig_host}:${local.kube_api_port}"

  # KubePrism
  kube_prism_host = "127.0.0.1"
  kube_prism_port = 7445

  # Staged machine configuration changes only take effect on the next reboot. Unless
  # something reboots the node, a staged change sits pending indefinitely, so the
  # module issues the reboot itself. Only meaningful for the two apply modes that can
  # produce a staged result.
  talos_staged_configuration_automatic_reboot_enabled = (
    var.talos_staged_configuration_automatic_reboot_enabled &&
    contains(["staged", "staged_if_needing_reboot"], var.talos_machine_configuration_apply_mode)
  )

  # Talos Control
  talosctl_commands = templatefile("${path.module}/templates/talosctl_commands.sh.tftpl", {
    talos_upgrade_debug                 = var.talos_upgrade_debug
    talos_upgrade_force                 = var.talos_upgrade_force
    talos_upgrade_insecure              = var.talos_upgrade_insecure
    talos_upgrade_stage                 = var.talos_upgrade_stage
    talos_upgrade_preserve              = var.talos_upgrade_preserve
    talos_upgrade_legacy                = var.talos_upgrade_legacy
    talos_upgrade_reboot_mode           = var.talos_upgrade_reboot_mode
    talos_reboot_debug                  = var.talos_reboot_debug
    talos_reboot_mode                   = var.talos_reboot_mode
    talos_installer_image_url           = local.talos_installer_image_url
    talosctl_retries                    = var.talosctl_retries
    healthcheck_enabled                 = var.cluster_healthcheck_enabled
    talos_primary_node                  = local.talos_primary_node_private_ipv4
    kube_api_url                        = local.kubeconfig_url
    kubernetes_version                  = var.kubernetes_version
    kubernetes_apiserver_image          = var.kubernetes_apiserver_image
    kubernetes_controller_manager_image = var.kubernetes_controller_manager_image
    kubernetes_scheduler_image          = var.kubernetes_scheduler_image
    kubernetes_proxy_image              = var.kubernetes_proxy_image
    kubernetes_kubelet_image            = var.kubernetes_kubelet_image
    control_plane_nodes                 = local.control_plane_private_ipv4_list
    worker_nodes                        = local.worker_private_ipv4_list
  })

  # Cluster Status
  # cluster_initialized = length(data.vcd_vapp.state.metadata_entry) > 0
  cluster_initialized = length(data.vcd_resource_list.state.list) > 0

  cluster_initialized_key = "k8s_${var.cluster_name}_state"
}

data "vcd_resource_list" "state" {
  name          = local.cluster_initialized_key
  resource_type = "vcd_library_certificate"
  name_regex    = local.cluster_initialized_key
}

resource "talos_machine_secrets" "this" {
  talos_version = var.talos_version

  lifecycle {
    prevent_destroy = true
  }
}

resource "terraform_data" "upgrade_control_plane" {
  triggers_replace = [
    var.talos_version,
    local.talos_schematic_id
  ]

  provisioner "local-exec" {
    when  = create
    quiet = true
    command = local.cluster_initialized ? join("\n", [
      "set -eu",
      local.talosctl_commands,
      "printf '%s\\n' \"Start upgrading Control Plane Nodes\"",
      templatefile("${path.module}/templates/talos_upgrade.sh.tftpl", {
        upgrade_nodes      = local.control_plane_private_ipv4_list
        talos_version      = var.talos_version
        talos_schematic_id = local.talos_schematic_id
      }),
      "printf '%s\\n' \"Control Plane Nodes upgraded successfully\"",
    ]) : "printf '%s\\n' \"Cluster not initialized, skipping Control Plane Node upgrade\""

    environment = {
      TALOSCONFIG = nonsensitive(data.talos_client_configuration.this.talos_config)
    }
  }

  depends_on = [
    data.external.talosctl_version_check,
    data.talos_machine_configuration.control_plane,
    data.talos_client_configuration.this
  ]
}

resource "terraform_data" "upgrade_worker" {
  triggers_replace = [
    var.talos_version,
    local.talos_schematic_id
  ]

  provisioner "local-exec" {
    when  = create
    quiet = true
    command = local.cluster_initialized ? join("\n", [
      "set -eu",
      local.talosctl_commands,
      "printf '%s\\n' \"Start upgrading Worker Nodes\"",
      templatefile("${path.module}/templates/talos_upgrade.sh.tftpl", {
        upgrade_nodes      = local.worker_private_ipv4_list
        talos_version      = var.talos_version
        talos_schematic_id = local.talos_schematic_id
      }),
      "printf '%s\\n' \"Worker Nodes upgraded successfully\"",
    ]) : "printf '%s\\n' \"Cluster not initialized, skipping Worker Node upgrade\""

    environment = {
      TALOSCONFIG = nonsensitive(data.talos_client_configuration.this.talos_config)
    }
  }

  depends_on = [
    data.external.talosctl_version_check,
    data.talos_machine_configuration.worker,
    terraform_data.upgrade_control_plane
  ]
}

resource "terraform_data" "upgrade_kubernetes" {
  triggers_replace = [
    var.kubernetes_version,
    var.kubernetes_apiserver_image,
    var.kubernetes_controller_manager_image,
    var.kubernetes_scheduler_image,
    var.kubernetes_proxy_image,
    var.kubernetes_kubelet_image,
  ]

  provisioner "local-exec" {
    when  = create
    quiet = true
    command = join("\n", [
      "set -eu",
      local.cluster_initialized ? join("\n", [
        local.talosctl_commands,
        "printf '%s\\n' \"Start upgrading Kubernetes\"",
        templatefile("${path.module}/templates/talos_upgrade_k8s.sh.tftpl", {}),
        "printf '%s\\n' \"Kubernetes upgraded successfully\"",
      ]) : "printf '%s\\n' \"Cluster not initialized, skipping Kubernetes upgrade\"",
    ])

    environment = {
      TALOSCONFIG = nonsensitive(data.talos_client_configuration.this.talos_config)
    }
  }

  depends_on = [
    data.external.talosctl_version_check,
    terraform_data.upgrade_control_plane,
    terraform_data.upgrade_worker
  ]
}

resource "talos_machine_configuration_apply" "control_plane" {
  for_each = { for control_plane in vcd_vapp_vm.control_plane : control_plane.name => control_plane }

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.control_plane[each.key].machine_configuration
  endpoint                    = var.cluster_access == "private" ? tolist(each.value.network)[0].ip : coalesce(each.value.ipv4_address, each.value.ipv6_address)
  node                        = tolist(each.value.network)[0].ip
  apply_mode                  = var.talos_machine_configuration_apply_mode

  on_destroy = {
    graceful = var.cluster_graceful_destroy
    reset    = true
    reboot   = false
  }

  depends_on = [
    vcd_nsxt_alb_virtual_service.kube_api,
    terraform_data.upgrade_kubernetes
  ]
}

resource "terraform_data" "talos_staged_configuration_reboot_control_plane" {
  count = local.talos_staged_configuration_automatic_reboot_enabled ? 1 : 0

  triggers_replace = [
    nonsensitive(sha1(jsonencode({
      for k, v in data.talos_machine_configuration.control_plane :
      k => v.machine_configuration
    })))
  ]

  provisioner "local-exec" {
    when  = create
    quiet = true
    command = anytrue([for _, v in talos_machine_configuration_apply.control_plane : v.resolved_apply_mode == "staged"]) ? join("\n", [
      "set -eu",
      local.talosctl_commands,
      templatefile("${path.module}/templates/talos_reboot.sh.tftpl", {
        target_nodes        = local.control_plane_private_ipv4_list
        healthcheck_enabled = local.cluster_initialized
      })
    ]) : "printf '%s\\n' \"No control plane configuration changes were applied in staged mode. Skipping reboot.\""

    environment = merge(
      { TALOSCONFIG = nonsensitive(data.talos_client_configuration.this.talos_config) },
      {
        for _, apply in talos_machine_configuration_apply.control_plane :
        "TALOS_APPLY_MODE_${replace(apply.node, ".", "_")}" => apply.resolved_apply_mode
      }
    )
  }

  depends_on = [
    data.external.talosctl_version_check,
    talos_machine_configuration_apply.control_plane
  ]
}

resource "talos_machine_configuration_apply" "worker" {
  for_each = { for worker in vcd_vapp_vm.worker : worker.name => worker }

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker[each.key].machine_configuration
  endpoint                    = var.cluster_access == "private" ? tolist(each.value.network)[0].ip : coalesce(each.value.ipv4_address, each.value.ipv6_address)
  node                        = tolist(each.value.network)[0].ip
  apply_mode                  = var.talos_machine_configuration_apply_mode

  lifecycle {
    replace_triggered_by = [vcd_vapp_vm.worker[each.key].id]
  }

  on_destroy = {
    graceful = var.cluster_graceful_destroy
    reset    = true
    reboot   = false
  }

  depends_on = [
    terraform_data.upgrade_kubernetes,
    talos_machine_configuration_apply.control_plane,
    terraform_data.talos_staged_configuration_reboot_control_plane
  ]
}

resource "terraform_data" "talos_staged_configuration_reboot_worker" {
  count = local.talos_staged_configuration_automatic_reboot_enabled ? 1 : 0

  triggers_replace = [
    nonsensitive(sha1(jsonencode({
      for k, v in data.talos_machine_configuration.worker :
      k => v.machine_configuration
    })))
  ]

  provisioner "local-exec" {
    when  = create
    quiet = true
    command = anytrue([for _, v in talos_machine_configuration_apply.worker : v.resolved_apply_mode == "staged"]) ? join("\n", [
      "set -eu",
      local.talosctl_commands,
      templatefile("${path.module}/templates/talos_reboot.sh.tftpl", {
        target_nodes        = local.worker_private_ipv4_list
        healthcheck_enabled = local.cluster_initialized
      })
    ]) : "printf '%s\\n' \"No worker configuration changes were applied in staged mode. Skipping reboot.\""

    environment = merge(
      { TALOSCONFIG = nonsensitive(data.talos_client_configuration.this.talos_config) },
      {
        for _, apply in talos_machine_configuration_apply.worker :
        "TALOS_APPLY_MODE_${replace(apply.node, ".", "_")}" => apply.resolved_apply_mode
      }
    )
  }

  depends_on = [
    data.external.talosctl_version_check,
    talos_machine_configuration_apply.worker
  ]
}

resource "talos_machine_bootstrap" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoint             = local.talos_transport_primary_endpoint
  node                 = local.talos_primary_node_private_ipv4

  depends_on = [
    talos_machine_configuration_apply.control_plane,
    talos_machine_configuration_apply.worker
  ]
}

resource "terraform_data" "synchronize_manifests" {
  triggers_replace = [
    sha1(jsonencode(local.talos_inline_manifests)),
    sha1(jsonencode(local.talos_manifests)),
  ]

  provisioner "local-exec" {
    when  = create
    quiet = true
    command = join("\n", [
      "set -eu",
      local.cluster_initialized ? join("\n", [
        local.talosctl_commands,
        "printf '%s\\n' \"Start synchronizing Kubernetes manifests\"",
        templatefile("${path.module}/templates/talos_upgrade_k8s.sh.tftpl", {}),
        "printf '%s\\n' \"Kubernetes manifests synchronized successfully\"",
      ]) : "printf '%s\\n' \"Cluster not initialized, skipping Kubernetes manifest synchronization\"",
    ])

    environment = {
      TALOSCONFIG = nonsensitive(data.talos_client_configuration.this.talos_config)
    }
  }

  depends_on = [
    data.external.talosctl_version_check,
    talos_machine_bootstrap.this,
    talos_machine_configuration_apply.control_plane,
    talos_machine_configuration_apply.worker,
    terraform_data.talos_staged_configuration_reboot_control_plane,
    terraform_data.talos_staged_configuration_reboot_worker,
  ]
}

resource "tls_private_key" "state" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "state" {
  private_key_pem = tls_private_key.state.private_key_pem

  subject { common_name = var.cluster_name }
  allowed_uses          = ["server_auth"]
  validity_period_hours = 876600
}

resource "vcd_library_certificate" "state" {
  description = "initialized"
  alias       = local.cluster_initialized_key

  private_key = tls_private_key.state.private_key_pem_pkcs8
  certificate = trimspace(tls_self_signed_cert.state.cert_pem)

  depends_on = [terraform_data.synchronize_manifests]
}


resource "terraform_data" "talos_health_data" {
  input = {
    current_ip          = local.current_ip
    endpoints           = local.talos_transport_endpoints
    control_plane_nodes = local.control_plane_private_ipv4_list
    worker_nodes        = local.worker_private_ipv4_list
    kube_api_url        = local.kube_api_url_transport
  }
}

data "http" "kube_api_health" {
  count = var.cluster_healthcheck_enabled ? 1 : 0

  url      = "${terraform_data.talos_health_data.output.kube_api_url}/version"
  insecure = true

  retry {
    attempts     = 60
    min_delay_ms = 5000
    max_delay_ms = 5000
  }

  lifecycle {
    postcondition {
      condition     = self.status_code == 401
      error_message = "Status code invalid"
    }
  }

  depends_on = [terraform_data.synchronize_manifests]
}

data "talos_cluster_health" "this" {
  count = var.cluster_healthcheck_enabled && (var.cluster_access == "private") ? 1 : 0

  client_configuration   = talos_machine_secrets.this.client_configuration
  endpoints              = terraform_data.talos_health_data.output.endpoints
  control_plane_nodes    = terraform_data.talos_health_data.output.control_plane_nodes
  worker_nodes           = terraform_data.talos_health_data.output.worker_nodes
  skip_kubernetes_checks = false

  depends_on = [data.http.kube_api_health]
}
