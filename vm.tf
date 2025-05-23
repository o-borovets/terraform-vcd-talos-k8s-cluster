resource "vcd_vapp" "this" {
  name = var.cluster_name

  lifecycle {
    ignore_changes = [metadata_entry]
  }
}

resource "vcd_vapp_org_network" "this" {
  vapp_name        = vcd_vapp.this.name
  org_network_name = vcd_network_routed_v2.this.name
}

locals {
  all_server_types = toset(
    concat(
      local.control_plane_nodepools[*].server_type,
      local.worker_nodepools[*].server_type
    )
  )
}

data "vcd_vm_sizing_policy" "lookup" {
  for_each = local.all_server_types

  name = each.key
}

resource "vcd_vapp_vm" "control_plane" {
  vapp_name = vcd_vapp.this.name

  for_each = merge([
    for np_index in range(length(local.control_plane_nodepools)) : {
      for cp_index in range(local.control_plane_nodepools[np_index].count) : "${var.cluster_name}-${local.control_plane_nodepools[np_index].name}-${cp_index + 1}" => {
        sizing_policy_id = data.vcd_vm_sizing_policy.lookup[local.control_plane_nodepools[np_index].server_type].id,

        labels = local.control_plane_nodepools[np_index].labels,

        network = {
          type = "org"
          name = vcd_network_routed_v2.this.name
          ip = cidrhost(
            tolist(vcd_nsxt_ip_set.control_plane.ip_addresses)[0],
            np_index * 10 + cp_index + 1
          )
          ip_allocation_mode = "MANUAL"
        }

        firmware        = local.control_plane_nodepools[np_index].firmware,
        efi_secure_boot = local.control_plane_nodepools[np_index].secure_boot,

        extra_parameters = local.control_plane_nodepools[np_index].extra_parameters,
      }
    }
  ]...)

  vapp_template_id = data.vcd_catalog_vapp_template.talos-boot-image.id

  name          = each.key
  computer_name = each.key

  sizing_policy_id = each.value.sizing_policy_id

  # os_type = "other6xLinux64Guest"

  network {
    type               = each.value.network.type
    name               = each.value.network.name
    ip                 = each.value.network.ip
    ip_allocation_mode = each.value.network.ip_allocation_mode
  }

  guest_properties = {
    "metadata" = base64encode(yamlencode({
      local-hostname = each.key,
      network = {
        version = 2,
        ethernets = {
          eth0 = {
            addresses = ["${each.value.network.ip}/${split("/", local.network_ipv4_cidr)[1]}"]
            nameservers = {
              addresses = ["1.1.1.1"]
            }
            gateway4 = local.network_ipv4_gateway
          }
        }
      }
    }))
  }
  firmware = each.value.firmware

  boot_options {
    efi_secure_boot = each.value.efi_secure_boot
  }

  dynamic "set_extra_config" {
    for_each = each.value.extra_parameters
    content {
      key   = set_extra_config.key
      value = set_extra_config.value
    }
  }

  dynamic "metadata_entry" {
    for_each = each.value.labels
    content {
      key         = metadata_entry.key
      value       = metadata_entry.value
      type        = "MetadataStringValue"
      user_access = "READWRITE"
      is_system   = false
    }
  }

  lifecycle {
    ignore_changes = [
      vapp_template_id,
      disk, # can cause conflicts with CSI. TODO: Find a workaround to keep attached disks that are not managed by terraform
    ]
  }
}

###############

resource "vcd_vapp_vm" "worker" {
  vapp_name = vcd_vapp.this.name

  for_each = merge([
    for np_index in range(length(local.worker_nodepools)) : {
      for wkr_index in range(local.worker_nodepools[np_index].count) : "${var.cluster_name}-${local.worker_nodepools[np_index].name}-${wkr_index + 1}" => {
        sizing_policy_id = data.vcd_vm_sizing_policy.lookup[local.worker_nodepools[np_index].server_type].id,

        labels = merge(
          local.worker_nodepools[np_index].labels,
          { cluster : var.cluster_name },
          { role : "worker" }
        ),

        ipv4_private = cidrhost(
          tolist(vcd_nsxt_ip_set.worker[local.worker_nodepools[np_index].name].ip_addresses)[0],
          wkr_index + 1
        ),

        firmware        = local.worker_nodepools[np_index].firmware,
        efi_secure_boot = local.worker_nodepools[np_index].secure_boot,

        extra_parameters = local.worker_nodepools[np_index].extra_parameters,
      }
    }
  ]...)

  vapp_template_id = data.vcd_catalog_vapp_template.talos-boot-image.id

  name          = each.key
  computer_name = each.key

  sizing_policy_id = each.value.sizing_policy_id

  network {
    type               = "org"
    name               = vcd_network_routed_v2.this.name
    ip                 = each.value.ipv4_private
    ip_allocation_mode = "MANUAL"
  }

  guest_properties = {
    "metadata" = base64encode(yamlencode({
      local-hostname = each.key,
      network = {
        version = 2,
        ethernets = {
          eth0 = {
            addresses = ["${each.value.ipv4_private}/${split("/", local.network_ipv4_cidr)[1]}"]
            nameservers = {
              addresses = ["1.1.1.1"]
            }
            gateway4 = local.network_ipv4_gateway
          }
        }
      }
    }))
  }

  firmware = each.value.firmware

  boot_options {
    efi_secure_boot = each.value.efi_secure_boot
  }

  dynamic "set_extra_config" {
    for_each = each.value.extra_parameters
    content {
      key   = set_extra_config.key
      value = set_extra_config.value
    }
  }

  dynamic "metadata_entry" {
    for_each = each.value.labels
    content {
      key         = metadata_entry.key
      value       = metadata_entry.value
      type        = "MetadataStringValue"
      user_access = "READWRITE"
      is_system   = false
    }
  }

  lifecycle {
    ignore_changes = [
      vapp_template_id,
      disk, # can cause conflicts with CSI. TODO: Find a workaround to keep attached disks that are not managed by terraform
    ]
  }
}
