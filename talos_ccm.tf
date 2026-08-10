locals {
  # Vendored snapshot of the upstream talos-cloud-controller-manager DaemonSet
  # bundle, previously fetched by Talos itself from
  #   raw.githubusercontent.com/siderolabs/talos-cloud-controller-manager/
  #     <version>/docs/deploy/cloud-controller-manager-daemonset.yml
  #
  # It is inlined rather than linked for one reason: the URL delivers upstream's
  # stock --controllers list, which includes cloud-node. On VCD that races the
  # VMware Cloud Director CCM, which runs its own cloud-node, and the winner
  # decides the node's providerID scheme. Editing the live DaemonSet does not
  # help — Talos re-applies extraManifests whenever the machine configuration is
  # applied, i.e. during an upgrade walk, which is the worst possible moment for
  # the setting to revert. The controller split has to live here.
  #
  # Which controller belongs where:
  #   node-csr-approval      only talos-ccm has it. It approves kubelet-serving
  #                          CSRs, which is what lets a newly added or replaced
  #                          node finish registering. Keep it here.
  #   cloud-node             both have it. Leave it to the VCD CCM so providerID
  #                          is consistently the vmware-cloud-director:// scheme.
  #   cloud-node-lifecycle   both have it; enabled in the VCD CCM, deselected
  #                          here. It resolves nodes via providerID, so it has to
  #                          stay with whichever CCM owns that scheme.
  #
  # The cloud provider plumbing stays even with no cloud controllers enabled:
  # the binary refuses to start on an empty --cloud-provider and initialises the
  # Talos provider before the controller loop runs. So --cloud-provider,
  # --cloud-config, the ConfigMap, the talos.dev ServiceAccount and the
  # talos-secrets volume all have to be reproduced verbatim.
  #
  # Structure is a snapshot of the v1.9.0 bundle (upstream chart 0.4.4); only
  # the image tag follows var.talos_ccm_version. RE-VENDOR THIS FILE WHEN
  # BUMPING THAT VARIABLE — later releases change the manifest, not just the
  # tag. v1.13.0 in particular moves --secure-port from 50258 to 10458, and a
  # tag-only bump would leave the port here disagreeing with the release.
  talos_ccm_manifest = {
    name     = "talos-cloud-controller-manager"
    contents = <<-EOF
      ---
      apiVersion: v1
      kind: ServiceAccount
      metadata:
        name: talos-cloud-controller-manager
        labels:
          helm.sh/chart: talos-cloud-controller-manager-0.4.4
          app.kubernetes.io/name: talos-cloud-controller-manager
          app.kubernetes.io/instance: talos-cloud-controller-manager
          app.kubernetes.io/version: "${var.talos_ccm_version}"
          app.kubernetes.io/managed-by: Helm
        namespace: kube-system
      ---
      apiVersion: talos.dev/v1alpha1
      kind: ServiceAccount
      metadata:
        name: talos-cloud-controller-manager-talos-secrets
        labels:
          helm.sh/chart: talos-cloud-controller-manager-0.4.4
          app.kubernetes.io/name: talos-cloud-controller-manager
          app.kubernetes.io/instance: talos-cloud-controller-manager
          app.kubernetes.io/version: "${var.talos_ccm_version}"
          app.kubernetes.io/managed-by: Helm
        namespace: kube-system
      spec:
        roles:
          - os:reader
      ---
      apiVersion: v1
      kind: ConfigMap
      metadata:
        name: talos-cloud-controller-manager
        labels:
          helm.sh/chart: talos-cloud-controller-manager-0.4.4
          app.kubernetes.io/name: talos-cloud-controller-manager
          app.kubernetes.io/instance: talos-cloud-controller-manager
          app.kubernetes.io/version: "${var.talos_ccm_version}"
          app.kubernetes.io/managed-by: Helm
        namespace: kube-system
      data:
        ccm-config.yaml: |
          global:
      ---
      apiVersion: rbac.authorization.k8s.io/v1
      kind: ClusterRole
      metadata:
        name: system:talos-cloud-controller-manager
        labels:
          helm.sh/chart: talos-cloud-controller-manager-0.4.4
          app.kubernetes.io/name: talos-cloud-controller-manager
          app.kubernetes.io/instance: talos-cloud-controller-manager
          app.kubernetes.io/version: "${var.talos_ccm_version}"
          app.kubernetes.io/managed-by: Helm
      rules:
      - apiGroups:
        - coordination.k8s.io
        resources:
        - leases
        verbs:
        - get
        - create
        - update
      - apiGroups:
        - ""
        resources:
        - events
        verbs:
        - create
        - patch
        - update
      - apiGroups:
        - ""
        resources:
        - nodes
        verbs:
        - get
        - list
        - watch
        - update
        - patch
      - apiGroups:
        - ""
        resources:
        - nodes/status
        verbs:
        - patch
      - apiGroups:
        - ""
        resources:
        - serviceaccounts
        verbs:
        - create
        - get
      - apiGroups:
        - ""
        resources:
        - serviceaccounts/token
        verbs:
        - create
      - apiGroups:
        - certificates.k8s.io
        resources:
        - certificatesigningrequests
        verbs:
        - list
        - watch
      - apiGroups:
        - certificates.k8s.io
        resources:
        - certificatesigningrequests/approval
        verbs:
        - update
      - apiGroups:
        - certificates.k8s.io
        resources:
        - signers
        resourceNames:
        - kubernetes.io/kubelet-serving
        verbs:
        - approve
      ---
      kind: ClusterRoleBinding
      apiVersion: rbac.authorization.k8s.io/v1
      metadata:
        name: system:talos-cloud-controller-manager
      roleRef:
        apiGroup: rbac.authorization.k8s.io
        kind: ClusterRole
        name: system:talos-cloud-controller-manager
      subjects:
      - kind: ServiceAccount
        name: talos-cloud-controller-manager
        namespace: kube-system
      ---
      apiVersion: rbac.authorization.k8s.io/v1
      kind: RoleBinding
      metadata:
        name: system:talos-cloud-controller-manager:extension-apiserver-authentication-reader
        namespace: kube-system
      roleRef:
        apiGroup: rbac.authorization.k8s.io
        kind: Role
        name: extension-apiserver-authentication-reader
      subjects:
        - kind: ServiceAccount
          name: talos-cloud-controller-manager
          namespace: kube-system
      ---
      apiVersion: v1
      kind: Service
      metadata:
        name: talos-cloud-controller-manager
        labels:
          helm.sh/chart: talos-cloud-controller-manager-0.4.4
          app.kubernetes.io/name: talos-cloud-controller-manager
          app.kubernetes.io/instance: talos-cloud-controller-manager
          app.kubernetes.io/version: "${var.talos_ccm_version}"
          app.kubernetes.io/managed-by: Helm
        namespace: kube-system
      spec:
        clusterIP: None
        type: ClusterIP
        ports:
          - name: metrics
            port: ${var.talos_ccm_secure_port}
            targetPort: ${var.talos_ccm_secure_port}
            protocol: TCP
        selector:
              app.kubernetes.io/name: talos-cloud-controller-manager
              app.kubernetes.io/instance: talos-cloud-controller-manager
      ---
      apiVersion: apps/v1
      kind: DaemonSet
      metadata:
        name: talos-cloud-controller-manager
        labels:
          helm.sh/chart: talos-cloud-controller-manager-0.4.4
          app.kubernetes.io/name: talos-cloud-controller-manager
          app.kubernetes.io/instance: talos-cloud-controller-manager
          app.kubernetes.io/version: "${var.talos_ccm_version}"
          app.kubernetes.io/managed-by: Helm
        namespace: kube-system
      spec:
        updateStrategy:
          type: RollingUpdate
        selector:
          matchLabels:
            app.kubernetes.io/name: talos-cloud-controller-manager
            app.kubernetes.io/instance: talos-cloud-controller-manager
        template:
          metadata:
            labels:
              app.kubernetes.io/name: talos-cloud-controller-manager
              app.kubernetes.io/instance: talos-cloud-controller-manager
          spec:
            serviceAccountName: talos-cloud-controller-manager
            securityContext:
              fsGroup: 10258
              fsGroupChangePolicy: OnRootMismatch
              runAsGroup: 10258
              runAsNonRoot: true
              runAsUser: 10258
            dnsPolicy: ClusterFirstWithHostNet
            hostNetwork: true
            priorityClassName: system-cluster-critical
            containers:
              - name: talos-cloud-controller-manager
                securityContext:
                  allowPrivilegeEscalation: false
                  capabilities:
                    drop:
                    - ALL
                  seccompProfile:
                    type: RuntimeDefault
                image: "${var.talos_ccm_image}:${var.talos_ccm_version}"
                imagePullPolicy: IfNotPresent
                command: ["/talos-cloud-controller-manager"]
                args:
                  - --v=2
                  - --cloud-provider=talos
                  - --cloud-config=/etc/talos/ccm-config.yaml
                  - --controllers=${join(",", var.talos_ccm_controllers)}
                  - --leader-elect-resource-name=cloud-controller-manager-talos
                  - --use-service-account-credentials
                  - --secure-port=${var.talos_ccm_secure_port}
                  - --authorization-always-allow-paths=/healthz,/livez,/readyz,/metrics
                env:
                  - name: TALOS_ENDPOINTS
                    valueFrom:
                      fieldRef:
                        fieldPath: status.podIP
                  - name: KUBERNETES_SERVICE_HOST
                    valueFrom:
                      fieldRef:
                        fieldPath: status.podIP
                  - name: KUBERNETES_SERVICE_PORT
                    value: "6443"
                ports:
                  - name: metrics
                    containerPort: ${var.talos_ccm_secure_port}
                    protocol: TCP
                livenessProbe:
                  httpGet:
                    path: /healthz
                    port: metrics
                    scheme: HTTPS
                  initialDelaySeconds: 20
                  periodSeconds: 30
                  timeoutSeconds: 5
                resources:
                  requests:
                    cpu: 10m
                    memory: 64Mi
                volumeMounts:
                  - name: cloud-config
                    mountPath: /etc/talos
                    readOnly: true
                  - name: talos-secrets
                    mountPath: /var/run/secrets/talos.dev
                    readOnly: true
            nodeSelector:
              node-role.kubernetes.io/control-plane: ""
            tolerations:
              - effect: NoSchedule
                key: node-role.kubernetes.io/control-plane
                operator: Exists
              - effect: NoSchedule
                key: node.cloudprovider.kubernetes.io/uninitialized
                operator: Exists
              - effect: NoSchedule
                key: node.kubernetes.io/not-ready
                operator: Exists
            volumes:
              - name: cloud-config
                configMap:
                  name: talos-cloud-controller-manager
                  defaultMode: 416 # 0640
              - name: talos-secrets
                secret:
                  secretName: talos-cloud-controller-manager-talos-secrets
                  defaultMode: 416 # 0640
    EOF
  }
}
