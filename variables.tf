# Cluster Configuration
variable "cluster_name" {
  type        = string
  description = "Specifies the name of the cluster. This name is used to identify the cluster within the infrastructure and should be unique across all deployments."

  validation {
    condition     = can(regex("^[a-z0-9](?:[a-z0-9-]{0,30}[a-z0-9])?$", var.cluster_name))
    error_message = "The cluster name must start and end with a lowercase letter or number, can contain hyphens, and must be no longer than 32 characters."
  }
}

variable "cluster_domain" {
  type        = string
  default     = "cluster.local"
  description = "Specifies the domain name used by the cluster. This domain name is integral for internal networking and service discovery within the cluster. The default is 'cluster.local', which is commonly used for local Kubernetes clusters."

  validation {
    condition     = can(regex("^(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\\.)*(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?)$", var.cluster_domain))
    error_message = "The cluster domain must be a valid domain: each segment must start and end with a letter or number, can contain hyphens, and each segment must be no longer than 63 characters."
  }
}

variable "cluster_access" {
  type        = string
  default     = "public"
  description = "Defines how the cluster is accessed externally. Specifies if access should be through public or private IPs."

  validation {
    condition     = contains(["public", "private"], var.cluster_access)
    error_message = "Invalid value for 'cluster_access'. Valid options are 'public' or 'private'."
  }
}

variable "kubeconfig_endpoint_mode" {
  type        = string
  default     = "auto"
  description = "Controls which endpoint is written into the generated kubeconfig. Use explicit modes to separate user-facing kubeconfig access from the module's own transport path."

  validation {
    condition     = contains(["auto", "public_ip", "private_ip", "public_endpoint", "private_endpoint"], var.kubeconfig_endpoint_mode)
    error_message = "The kubeconfig_endpoint_mode must be 'auto', 'public_ip', 'private_ip', 'public_endpoint', or 'private_endpoint'."
  }
}

variable "talosconfig_endpoints_mode" {
  type        = string
  default     = "auto"
  description = "Controls which control plane node addresses are written into the generated talosconfig. Talos recommends direct per-node IPs instead of a VIP or load-balanced hostname."

  validation {
    condition     = contains(["auto", "public_ip", "private_ip"], var.talosconfig_endpoints_mode)
    error_message = "The talosconfig_endpoints_mode must be 'auto', 'public_ip', or 'private_ip'."
  }
}

variable "cluster_kubeconfig_path" {
  type        = string
  default     = null
  description = "If not null, the kubeconfig will be written to a file speficified."
}

variable "cluster_talosconfig_path" {
  type        = string
  default     = null
  description = "If not null, the talosconfig will be written to a file speficified."
}

variable "cluster_graceful_destroy" {
  type        = bool
  default     = true
  description = "Determines whether a graceful destruction process is enabled for Talos nodes. When enabled, it ensures that nodes are properly drained and decommissioned before being destroyed, minimizing disruption in the cluster."
}

variable "cluster_healthcheck_enabled" {
  type        = bool
  default     = true
  description = "Determines whether are executed during cluster deployment and upgrade."
}

variable "cluster_delete_protection" {
  type        = bool
  default     = true
  description = "Adds delete protection for resources that support it."
}

# Client Tools
variable "client_prerequisites_check_enabled" {
  type        = bool
  default     = true
  description = "Controls whether a preflight check verifies that required client tools are installed before provisioning."
}

variable "talosctl_version_check_enabled" {
  type        = bool
  default     = true
  description = "Controls whether a preflight check verifies the local talosctl client version before provisioning."
}

variable "talosctl_retries" {
  type        = number
  default     = 10
  description = "Specifies how many times talosctl operations should retry before failing. This setting helps improve resilience against transient network issues or temporary API unavailability."

  validation {
    condition     = var.talosctl_retries >= 0
    error_message = "The talosctl retries value must be at least 0."
  }
}




# Firewall Configuration
# variable "firewall_use_current_ipv4" {
#   type        = bool
#   default     = null
#   description = "Determines whether the current IPv4 address is used for Talos and Kube API firewall rules. If `cluster_access` is set to `public`, the default is true."
# }

# variable "firewall_use_current_ipv6" {
#   type        = bool
#   default     = null
#   description = "Determines whether the current IPv6 /64 CIDR is used for Talos and Kube API firewall rules. If `cluster_access` is set to `public`, the default is true."
# }

# variable "firewall_extra_rules" {
#   type = list(object({
#     description     = string
#     direction       = string
#     source_ips      = optional(list(string), [])
#     destination_ips = optional(list(string), [])
#     protocol        = string
#     port            = optional(string)
#   }))
#   default     = []
#   description = "Additional firewall rules to apply to the cluster."

#   validation {
#     condition = alltrue([
#       for rule in var.firewall_extra_rules : (
#         rule.direction == "in" || rule.direction == "out"
#       )
#     ])
#     error_message = "Each rule must specify 'direction' as 'in' or 'out'."
#   }

#   validation {
#     condition = alltrue([
#       for rule in var.firewall_extra_rules : (
#         rule.protocol == "tcp" || rule.protocol == "udp" || rule.protocol == "icmp" ||
#         rule.protocol == "gre" || rule.protocol == "esp"
#       )
#     ])
#     error_message = "Each rule must specify 'protocol' as 'tcp', 'udp', 'icmp', 'gre', or 'esp'."
#   }

#   validation {
#     condition = alltrue([
#       for rule in var.firewall_extra_rules : (
#         (rule.direction == "in" && rule.source_ips != null && (rule.destination_ips == null || length(rule.destination_ips) == 0)) ||
#         (rule.direction == "out" && rule.destination_ips != null && (rule.source_ips == null || length(rule.source_ips) == 0))
#       )
#     ])
#     error_message = "For 'in' direction, 'source_ips' must be provided and 'destination_ips' must be null or empty. For 'out' direction, 'destination_ips' must be provided and 'source_ips' must be null or empty."
#   }

#   validation {
#     condition = alltrue([
#       for rule in var.firewall_extra_rules : (
#         (rule.protocol != "icmp" && rule.protocol != "gre" && rule.protocol != "esp") || (rule.port == null)
#       )
#     ])
#     error_message = "Port must not be specified when 'protocol' is 'icmp', 'gre', or 'esp'."
#   }

#   // Validation to ensure port is specified for protocols that have ports
#   validation {
#     condition = alltrue([
#       for rule in var.firewall_extra_rules : (
#         rule.protocol == "tcp" || rule.protocol == "udp" ? rule.port != null : true
#       )
#     ])
#     error_message = "Port must be specified when 'protocol' is 'tcp' or 'udp'."
#   }
# }

# variable "firewall_api_source" {
#   type        = list(string)
#   default     = null
#   description = "Source networks that have access to Kube and Talos API. If set, this overrides the firewall_use_current_ipv4 and firewall_use_current_ipv6 settings."
# }

# variable "firewall_kube_api_source" {
#   type        = list(string)
#   default     = null
#   description = "Source networks that have access to Kube API. If set, this overrides the firewall_use_current_ipv4 and firewall_use_current_ipv6 settings."
# }

# variable "firewall_talos_api_source" {
#   type        = list(string)
#   default     = null
#   description = "Source networks that have access to Talos API. If set, this overrides the firewall_use_current_ipv4 and firewall_use_current_ipv6 settings."
# }


# Control Plane
variable "control_plane_public_vip_ipv4_enabled" {
  type        = bool
  default     = false
  description = "If true, a floating IP will be created and assigned to the Control Plane nodes."
}

variable "control_plane_public_vip_ipv4_id" {
  type        = number
  default     = null
  description = "Specifies the Floating IP ID for the Control Plane nodes. A new floating IP will be created if this is set to null."
}

variable "control_plane_private_vip_ipv4_enabled" {
  type        = bool
  default     = true
  description = "If true, an alias IP will be created and assigned to the Control Plane nodes."
}

variable "kube_api_admission_control" {
  type        = list(any)
  default     = []
  description = "List of admission control settings for the Kube API. If set, this overrides the default admission control."
}

variable "control_plane_nodepools" {
  type = list(object({
    name = string
    # location    = string # rename to vdc
    type = string
    # backups     = optional(bool, false)
    # keep_disk   = optional(bool, false)
    labels      = optional(map(string), {})
    annotations = optional(map(string), {})
    taints      = optional(list(string), [])
    count       = optional(number, 1)

    firmware    = optional(string, "bios")
    secure_boot = optional(bool, false)

    extra_parameters = optional(map(string), {})

    internal_disks = optional(list(object({
      type       = string
      size_in_mb = number
    })), [])
  }))
  description = "Configures the number and attributes of Control Plane nodes."

  validation {
    condition     = length(var.control_plane_nodepools) == length(distinct([for np in var.control_plane_nodepools : np.name]))
    error_message = "Control Plane nodepool names must be unique to avoid configuration conflicts."
  }

  validation {
    condition = alltrue([
      for np in var.control_plane_nodepools : np.secure_boot == false || np.firmware == "efi"
    ])
    error_message = "secure_boot can be true only if firmware is 'efi'."
  }

  validation {
    condition     = sum([for np in var.control_plane_nodepools : np.count]) <= 9
    error_message = "The total count of all nodes in Control Plane nodepools must not exceed 9."
  }

  validation {
    condition     = sum([for np in var.control_plane_nodepools : np.count]) % 2 == 1
    error_message = "The sum of all Control Plane nodes must be odd to ensure high availability."
  }

  validation {
    condition = alltrue([
      for np in var.control_plane_nodepools : length(var.cluster_name) + length(np.name) <= 56
    ])
    error_message = "The combined length of the cluster name and any Control Plane nodepool name must not exceed 56 characters."
  }

  validation {
    condition = alltrue([
      for np in var.control_plane_nodepools : contains([
        "bios", "efi",
      ], np.firmware)
    ])
    error_message = "Each worker nodepool firmware must be one of: 'bios' or 'efi'"
  }
}

variable "control_plane_config_patches" {
  type        = list(any)
  default     = []
  description = "List of configuration patches applied to the Control Plane nodes."
}


# Worker
variable "worker_nodepools" {
  type = list(object({
    name        = string
    type        = string
    labels      = optional(map(string), {})
    annotations = optional(map(string), {})
    taints      = optional(list(string), [])
    count       = optional(number, 1)
    firmware    = optional(string, "bios")
    secure_boot = optional(bool, false)

    extra_parameters = optional(map(string), {})

    internal_disks = optional(list(object({
      type       = string
      size_in_mb = number
    })), [])
  }))
  default     = []
  description = "Defines configuration settings for Worker node pools within the cluster."

  validation {
    condition     = length(var.worker_nodepools) == length(distinct([for np in var.worker_nodepools : np.name]))
    error_message = "Worker nodepool names must be unique to avoid configuration conflicts."
  }

  validation {
    condition = alltrue([
      for np in var.worker_nodepools : np.secure_boot == false || np.firmware == "efi"
    ])
    error_message = "secure_boot can be true only if firmware is 'efi'."
  }

  validation {
    condition = sum(concat(
      [for worker_nodepool in var.worker_nodepools : coalesce(worker_nodepool.count, 1)],
      [for control_nodepool in var.control_plane_nodepools : coalesce(control_nodepool.count, 1)]
    )) <= 100
    error_message = "The total count of nodes in both worker and Control Plane nodepools must not exceed 100 to ensure manageable cluster size."
  }

  validation {
    condition = alltrue([
      for np in var.worker_nodepools : length(var.cluster_name) + length(np.name) <= 56
    ])
    error_message = "The combined length of the cluster name and any Worker nodepool name must not exceed 56 characters."
  }

  validation {
    condition = alltrue([
      for np in var.worker_nodepools : contains([
        "bios", "efi",
      ], np.firmware)
    ])
    error_message = "Each worker nodepool firmware must be one of: 'bios' or 'efi'"
  }
}

variable "worker_config_patches" {
  type        = list(any)
  default     = []
  description = "List of configuration patches applied to the Worker nodes."
}


# Talos
variable "talos_version" {
  type        = string
  default     = "v1.12.6"
  description = "Specifies the version of Talos to be used in generated machine configurations."
}

variable "talos_schematic_id" {
  type        = string
  default     = null
  description = "Specifies the Talos schematic ID used for selecting the specific Image and Installer versions in deployments. This has precedence over `talos_image_extensions`"
}

variable "talos_image_extensions" {
  type        = list(string)
  default     = []
  description = "Specifies Talos image extensions for additional functionality on top of the default Talos Linux capabilities. See: https://github.com/siderolabs/extensions"
}

variable "talos_upgrade_debug" {
  type        = bool
  default     = false
  description = "Enable debug operation from kernel logs during Talos upgrades. When true, --wait is set to true by talosctl."
}

variable "talos_upgrade_force" {
  type        = bool
  default     = false
  description = "Force the Talos upgrade by skipping etcd health and member checks."
}

variable "talos_upgrade_insecure" {
  type        = bool
  default     = false
  description = "Upgrade using the insecure (no auth) maintenance service."
}

variable "talos_upgrade_reboot_mode" {
  type        = string
  default     = null
  description = "Select the reboot mode during upgrade. Mode \"powercycle\" bypasses kexec. Valid values: \"default\" or \"powercycle\"."

  validation {
    condition     = var.talos_upgrade_reboot_mode == null ? true : contains(["default", "powercycle"], var.talos_upgrade_reboot_mode)
    error_message = "The talos_upgrade_reboot_mode must be \"default\" or \"powercycle\"."
  }
}

variable "talos_upgrade_stage" {
  type        = bool
  default     = false
  description = "Stage the Talos upgrade to perform it after a reboot. Legacy upgrade path only, see talos_upgrade_legacy."
}

variable "talos_upgrade_preserve" {
  type        = bool
  default     = true
  description = <<-EOT
    Preserve the contents of the EPHEMERAL partition (/var) across a Talos upgrade,
    rather than wiping it and letting the node rebuild from scratch.

    This matters most on control planes, where /var/lib/etcd lives: with preserve
    disabled, every upgraded control plane discards its etcd data and re-syncs from
    the surviving quorum members, so each node upgrade spends time at reduced
    redundancy. On workers it decides whether the container image cache and
    /var/lib/kubelet survive, i.e. whether every image is pulled again afterwards.

    Legacy upgrade path only, see talos_upgrade_legacy. Disable it deliberately when
    a node needs a clean ephemeral partition, for example to clear corrupted local
    state, and prefer doing that one node at a time rather than for a whole walk.
  EOT
}

variable "talos_upgrade_legacy" {
  type        = bool
  default     = false
  description = <<-EOT
    Force talosctl to use the legacy MachineService.Upgrade path instead of letting
    it choose. Leave false to let talosctl decide: it uses the newer
    LifecycleService.Upgrade API when the node already runs Talos >1.13.0-alpha.2
    and falls back to the legacy path otherwise.

    The choice is not cosmetic. talos_upgrade_preserve, talos_upgrade_force and
    talos_upgrade_stage are honoured only on the legacy path; the new path silently
    ignores them, and instead drains the node (cordon and evict) before rebooting.
    Set this to true when those flags must apply deterministically across a version
    walk that will cross 1.13 partway through. talosctl marks the legacy path
    deprecated, for removal in Talos 1.18.
  EOT
}

variable "talos_reboot_debug" {
  type        = bool
  default     = false
  description = "Enable debug operation from kernel logs during Talos reboots. When true, --wait is set to true by talosctl."
}

variable "talos_reboot_mode" {
  type        = string
  default     = null
  description = "Select the reboot mode. Mode \"powercycle\" bypasses kexec, and mode \"force\" skips graceful teardown. Valid values: \"default\", \"powercycle\", or \"force\"."

  validation {
    condition     = var.talos_reboot_mode == null ? true : contains(["default", "powercycle", "force"], var.talos_reboot_mode)
    error_message = "The talos_reboot_mode must be \"default\", \"powercycle\", or \"force\"."
  }
}

variable "talos_staged_configuration_automatic_reboot_enabled" {
  type        = bool
  default     = true
  description = "Determines whether nodes are rebooted automatically after Talos machine configuration changes are applied in 'staged' mode, or when 'staged_if_needing_reboot' resolves to 'staged' mode. Without this, a staged configuration sits pending until something else reboots the node."
}

variable "talos_discovery_kubernetes_enabled" {
  type        = bool
  default     = false
  description = "Enable or disable Kubernetes-based Talos discovery service. Deprecated as of Kubernetes v1.32, where the AuthorizeNodeWithSelectors feature gate is enabled by default."
}

variable "talos_discovery_service_enabled" {
  type        = bool
  default     = true
  description = "Enable or disable Sidero Labs public Talos discovery service."
}

variable "talos_kubelet_extra_mounts" {
  type = list(object({
    source      = string
    destination = optional(string)
    type        = optional(string, "bind")
    options     = optional(list(string), ["bind", "rshared", "rw"])
  }))
  default     = []
  description = "Defines extra kubelet mounts for Talos with configurable 'source', 'destination' (defaults to 'source' if unset), 'type' (defaults to 'bind'), and 'options' (defaults to ['bind', 'rshared', 'rw'])"

  validation {
    condition = (
      length(var.talos_kubelet_extra_mounts) ==
      length(toset([for mount in var.talos_kubelet_extra_mounts : coalesce(mount.destination, mount.source)])) &&
      true # (!var.longhorn_enabled || !contains([for mount in var.talos_kubelet_extra_mounts : coalesce(mount.destination, mount.source)], "/var/lib/longhorn"))
    )
    error_message = "Each destination in talos_kubelet_extra_mounts must be unique and cannot include the Longhorn default data path if Longhorn is enabled."
  }
}

variable "talos_extra_kernel_args" {
  type        = list(string)
  default     = []
  description = "Defines a list of extra kernel commandline parameters."
}

variable "talos_kernel_modules" {
  type = list(object({
    name       = string
    parameters = optional(list(string))
  }))
  default     = null
  description = "Defines a list of kernel modules to be loaded during system boot, along with optional parameters for each module. This allows for customized kernel behavior in the Talos environment."
}

variable "talos_machine_configuration_apply_mode" {
  type        = string
  default     = "auto"
  description = "Determines how changes to Talos machine configurations are applied. 'auto' applies changes immediately and reboots if necessary. 'reboot' applies changes and then reboots the node. 'no_reboot' applies changes immediately without a reboot, failing if a reboot is required. 'staged' stages changes for the next reboot. 'staged_if_needing_reboot' applies immediately when safe and stages only when a reboot is required."

  validation {
    condition     = contains(["auto", "reboot", "no_reboot", "staged", "staged_if_needing_reboot"], var.talos_machine_configuration_apply_mode)
    error_message = "The talos_machine_configuration_apply_mode must be 'auto', 'reboot', 'no_reboot', 'staged', or 'staged_if_needing_reboot'."
  }
}

variable "talos_sysctls_extra_args" {
  type        = map(string)
  default     = {}
  description = "Specifies a map of sysctl key-value pairs for configuring additional kernel parameters. These settings allow for detailed customization of the operating system's behavior at runtime."
}

variable "talos_state_partition_encryption_enabled" {
  type        = bool
  default     = true
  description = "Enables or disables encryption for the state (`/system/state`) partition. Attention: Changing this value for an existing cluster requires manual actions as per Talos documentation (https://www.talos.dev/latest/talos-guides/configuration/disk-encryption). Ignoring this may break your cluster."
}

variable "talos_ephemeral_partition_encryption_enabled" {
  type        = bool
  default     = true
  description = "Enables or disables encryption for the ephemeral (`/var`) partition. Attention: Changing this value for an existing cluster requires manual actions as per Talos documentation (https://www.talos.dev/latest/talos-guides/configuration/disk-encryption). Ignoring this may break your cluster."
}

variable "talos_ipv6_enabled" {
  type        = bool
  default     = true
  description = "Determines whether IPv6 is enabled for the Talos operating system. Enabling this setting configures the Talos OS to support IPv6 networking capabilities."
}

variable "talos_public_ipv4_enabled" {
  type        = bool
  default     = true
  description = "Determines whether public IPv4 addresses are enabled for nodes the cluster. If true, each node is assigned a public IPv4 address."
}

variable "talos_public_ipv6_enabled" {
  type        = bool
  default     = true
  description = "Determines whether public IPv6 addresses are enabled for nodes in the cluster. If true, each node is assigned a public IPv4 address."
}

variable "talos_extra_routes" {
  type        = list(string)
  default     = []
  description = "Specifies CIDR blocks to be added as extra routes for the internal network interface, using the Hetzner router (first usable IP in the network) as the gateway."

  validation {
    condition     = alltrue([for cidr in var.talos_extra_routes : can(regex("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$", cidr))])
    error_message = "All entries in extra_routes must be valid CIDR notations."
  }
}

variable "talos_coredns_enabled" {
  type        = bool
  default     = true
  description = "Determines whether CoreDNS is enabled in the Talos cluster. When enabled, CoreDNS serves as the primary DNS service provider in Kubernetes."
}

variable "talos_nameservers" {
  type = list(string)
  default = [
    "1.1.1.1", "8.8.8.8",
    # "2a01:4ff:ff00::add:1", "2a01:4ff:ff00::add:2"
  ]
  description = "Specifies a list of IPv4 and IPv6 nameserver addresses used for DNS resolution by nodes and CoreDNS within the cluster."
}

variable "talos_extra_host_entries" {
  type = list(object({
    ip      = string
    aliases = list(string)
  }))
  default     = []
  description = "Specifies additional host entries to be added on each node. Each entry must include an IP address and a list of aliases associated with that IP."
}

variable "talos_time_servers" {
  type = list(string)
  default = [
    "0.pool.ntp.org",
    "1.pool.ntp.org",
    "2.pool.ntp.org"
  ]
  description = "Specifies a list of time server addresses used for network time synchronization across the cluster. These servers ensure that all cluster nodes maintain accurate and synchronized time."
}

variable "talos_registries" {
  type        = any
  default     = null
  description = <<-EOF
    Specifies a list of registry mirrors to be used for container image retrieval. This configuration helps in specifying alternate sources or local mirrors for image registries, enhancing reliability and speed of image downloads.
    Example configuration:
    ```
    registries = {
      mirrors = {
        "docker.io" = {
          endpoints = [
            "http://localhost:5000",
            "https://docker.io"
          ]
        }
      }
    }
    ```
  EOF
}

variable "talos_service_log_destinations" {
  description = "List of objects defining remote destinations for Talos service logs."
  type = list(object({
    endpoint  = string
    format    = optional(string, "json_lines")
    extraTags = optional(map(string), {})
  }))
  default = []
}

# Kubernetes
variable "kubernetes_version" {
  type        = string
  default     = "v1.35.2" # https://github.com/kubernetes/kubernetes
  description = "Specifies the Kubernetes version to deploy."
}

variable "kubernetes_kubelet_extra_args" {
  type        = map(string)
  default     = {}
  description = "Specifies additional command-line arguments to pass to the kubelet service. These arguments can customize or override default kubelet configurations, allowing for tailored cluster behavior."
}

variable "kubernetes_kubelet_extra_config" {
  type        = any
  default     = {}
  description = "Specifies additional configuration settings for the kubelet service. These settings can customize or override default kubelet configurations, allowing for tailored cluster behavior."
}

variable "kubernetes_apiserver_image" {
  type        = string
  default     = null
  description = "Specifies a custom image repository for kube-apiserver (e.g., 'my-registry.io/kube-apiserver'). The version tag is appended automatically from kubernetes_version. When set, this image is used during both machine configuration and Kubernetes upgrades, preventing custom images from being reset to upstream defaults."

  validation {
    condition     = var.kubernetes_apiserver_image == null || can(regex("^[a-z0-9]([a-z0-9._-]*[a-z0-9])?(:[0-9]+)?(/[a-z0-9]([a-z0-9._-]*[a-z0-9])?)+$", var.kubernetes_apiserver_image))
    error_message = "The image must be a valid container image reference without a tag (e.g., 'my-registry.io/kube-apiserver'). The version tag is appended automatically from kubernetes_version."
  }
}

variable "kubernetes_controller_manager_image" {
  type        = string
  default     = null
  description = "Specifies a custom image repository for kube-controller-manager (e.g., 'my-registry.io/kube-controller-manager'). The version tag is appended automatically from kubernetes_version. When set, this image is used during both machine configuration and Kubernetes upgrades, preventing custom images from being reset to upstream defaults."

  validation {
    condition     = var.kubernetes_controller_manager_image == null || can(regex("^[a-z0-9]([a-z0-9._-]*[a-z0-9])?(:[0-9]+)?(/[a-z0-9]([a-z0-9._-]*[a-z0-9])?)+$", var.kubernetes_controller_manager_image))
    error_message = "The image must be a valid container image reference without a tag (e.g., 'my-registry.io/kube-controller-manager'). The version tag is appended automatically from kubernetes_version."
  }
}

variable "kubernetes_scheduler_image" {
  type        = string
  default     = null
  description = "Specifies a custom image repository for kube-scheduler (e.g., 'my-registry.io/kube-scheduler'). The version tag is appended automatically from kubernetes_version. When set, this image is used during both machine configuration and Kubernetes upgrades, preventing custom images from being reset to upstream defaults."

  validation {
    condition     = var.kubernetes_scheduler_image == null || can(regex("^[a-z0-9]([a-z0-9._-]*[a-z0-9])?(:[0-9]+)?(/[a-z0-9]([a-z0-9._-]*[a-z0-9])?)+$", var.kubernetes_scheduler_image))
    error_message = "The image must be a valid container image reference without a tag (e.g., 'my-registry.io/kube-scheduler'). The version tag is appended automatically from kubernetes_version."
  }
}

variable "kubernetes_proxy_image" {
  type        = string
  default     = null
  description = "Specifies a custom image repository for kube-proxy (e.g., 'my-registry.io/kube-proxy'). The version tag is appended automatically from kubernetes_version. When set, this image is used during both machine configuration and Kubernetes upgrades, preventing custom images from being reset to upstream defaults."

  validation {
    condition     = var.kubernetes_proxy_image == null || can(regex("^[a-z0-9]([a-z0-9._-]*[a-z0-9])?(:[0-9]+)?(/[a-z0-9]([a-z0-9._-]*[a-z0-9])?)+$", var.kubernetes_proxy_image))
    error_message = "The image must be a valid container image reference without a tag (e.g., 'my-registry.io/kube-proxy'). The version tag is appended automatically from kubernetes_version."
  }
}

variable "kubernetes_kubelet_image" {
  type        = string
  default     = null
  description = "Specifies a custom image repository for kubelet (e.g., 'my-registry.io/kubelet'). The version tag is appended automatically from kubernetes_version. When set, this image is used during both machine configuration and Kubernetes upgrades, preventing custom images from being reset to upstream defaults."

  validation {
    condition     = var.kubernetes_kubelet_image == null || can(regex("^[a-z0-9]([a-z0-9._-]*[a-z0-9])?(:[0-9]+)?(/[a-z0-9]([a-z0-9._-]*[a-z0-9])?)+$", var.kubernetes_kubelet_image))
    error_message = "The image must be a valid container image reference without a tag (e.g., 'my-registry.io/kubelet'). The version tag is appended automatically from kubernetes_version."
  }
}


# Kubernetes API
variable "kube_api_hostname" {
  type        = string
  default     = null
  description = "Optional public DNS hostname for the Kubernetes API. Use this with kubeconfig_endpoint_mode='public_endpoint' when kubeconfig should point at a stable public DNS or load balancer address."
}

variable "kube_api_private_hostname" {
  type        = string
  default     = null
  description = "Optional private DNS hostname for the Kubernetes API. Use this with kubeconfig_endpoint_mode='private_endpoint' when kubeconfig should point at a private VIP or split-horizon DNS name."
}

variable "kube_api_load_balancer_enabled" {
  type        = bool
  default     = false
  description = "Determines whether a load balancer is enabled for the Kubernetes API server. Enabling this setting provides high availability and distributed traffic management to the API server."
}

variable "kube_api_load_balancer_public_network_enabled" {
  type        = bool
  default     = null
  description = "Enables the public interface for the Kubernetes API load balancer. When enabled, the API is accessible publicly without a firewall."
}

variable "kube_api_extra_args" {
  type        = map(string)
  default     = {}
  description = "Specifies additional command-line arguments to be passed to the kube-apiserver. This allows for customization of the API server's behavior according to specific cluster requirements."
}


# Talos CCM
variable "talos_ccm_version" {
  type        = string
  default     = "v1.12.0" # https://github.com/siderolabs/talos-cloud-controller-manager
  description = "Specifies the version of the Talos Cloud Controller Manager (CCM) to use. This version controls cloud-specific integration features in the Talos operating system. The manifest in talos_ccm.tf is a snapshot of the v1.9.0 bundle shape; re-vendor it when changing this, because later releases change more than the image tag."
}

variable "talos_ccm_image" {
  type        = string
  default     = "ghcr.io/siderolabs/talos-cloud-controller-manager"
  description = "Container image repository for the Talos CCM, without a tag. Override to pull from a mirror."
}

variable "talos_ccm_controllers" {
  type        = list(string)
  default     = ["node-csr-approval"]
  description = <<-EOT
    Controllers the Talos CCM should run, passed through as --controllers.

    The default is deliberately narrower than upstream's
    ["cloud-node", "node-csr-approval"]. This module always deploys alongside the
    VMware Cloud Director CCM, which runs its own cloud-node and cloud-node-lifecycle;
    running cloud-node in both makes node initialisation a race whose winner sets the
    node's providerID, and the schemes are not interchangeable. node-csr-approval has
    no counterpart in the VCD CCM or in kube-controller-manager — which auto-approves
    only kubernetes.io/kube-apiserver-client-kubelet, never kubernetes.io/kubelet-serving
    — so it must stay with the Talos CCM.

    Do not use "*": upstream intends cloud-node-lifecycle to be disabled by default but
    registers the wrong constant for it, so the wildcard enables it and it fights the
    VCD CCM. An explicit list is unaffected by that bug.
  EOT

  validation {
    condition     = length(var.talos_ccm_controllers) > 0
    error_message = "The talos_ccm_controllers list must not be empty."
  }

  validation {
    condition = alltrue([
      for c in var.talos_ccm_controllers : contains([
        "cloud-node", "cloud-node-controller",
        "cloud-node-lifecycle", "cloud-node-lifecycle-controller",
        "route", "node-route-controller",
        "service", "service-lb-controller",
        "nodeipam", "node-ipam-controller",
        "node-csr-approval", "certificatesigningrequest-approving-controller",
      ], c)
    ])
    error_message = "Each entry in talos_ccm_controllers must be a controller name or alias recognised by the Talos CCM."
  }
}

variable "talos_ccm_secure_port" {
  type        = number
  default     = 50258
  description = "Port the Talos CCM serves metrics and health endpoints on. Upstream changed this from 50258 to 10458 in v1.13.0; changing it on a live cluster can deadlock the manifest sync, because the Service port list merges under server-side apply by (port, protocol) and the stale entry is co-owned by the CCM's own field manager. If that happens, delete the Service and DaemonSet in kube-system while the apply is still retrying."
}

variable "hcloud_network" {
  type = object({
    id = number
  })
  default     = null
  description = "The Hetzner network resource of an existing network."
}

variable "vcd_network" {
  type = object({
    edge_gateway = object({
      id                       = optional(string)
      name                     = optional(string)
      server_engine_group_name = optional(string)
    })
  })
  default = null
}
