locals {
  control_plane_nodepools = [
    for np in var.control_plane_nodepools : {
      name        = np.name,
      server_type = np.type,
      firmware    = np.firmware,
      secure_boot = np.secure_boot,
      labels = merge(
        np.labels,
        { nodepool = np.name }
      ),
      annotations = np.annotations,
      taints = concat(
        [for taint in np.taints : regex(
          "^(?P<key>[^=:]+)=?(?P<value>[^=:]*?):(?P<effect>.+)$",
          taint
        )],
        local.allow_scheduling_on_control_plane ? [] : [
          { key = "node-role.kubernetes.io/control-plane", value = "", effect = "NoSchedule" }
        ]
      ),
      count = np.count,
    }
  ]

  worker_nodepools = [
    for np in var.worker_nodepools : {
      name        = np.name,
      server_type = np.type,
      firmware    = np.firmware,
      secure_boot = np.secure_boot,
      labels = merge(
        np.labels,
        { nodepool = np.name }
      ),
      annotations = np.annotations,
      taints = [for taint in np.taints : regex(
        "^(?P<key>[^=:]+)=?(?P<value>[^=:]*?):(?P<effect>.+)$",
        taint
      )],
      count           = np.count,
    }
  ]


  control_plane_nodepools_map      = { for np in local.control_plane_nodepools : np.name => np }
  worker_nodepools_map             = { for np in local.worker_nodepools : np.name => np }

  control_plane_sum = sum(concat(
    [for np in local.control_plane_nodepools : np.count], [0]
  ))
  worker_sum = sum(concat(
    [for np in local.worker_nodepools : np.count if length(np.taints) == 0], [0]
  ))
}
