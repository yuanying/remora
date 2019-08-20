#!/usr/bin/env bash

set -eu
export LC_ALL=C

KUBE_TEMPLATE=${LOCAL_MANIFESTS_DIR}/kube-scheduler.yaml

cat << EOF > $KUBE_TEMPLATE
---
apiVersion: policy/v1beta1
kind: PodDisruptionBudget
metadata:
  name: kube-scheduler
  namespace: kube-system
spec:
  minAvailable: 1
  selector:
    matchLabels:
      tier: control-plane
      k8s-app: kube-scheduler
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: remora:kube-scheduler
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:kube-scheduler
subjects:
- kind: ServiceAccount
  name: kube-scheduler
  namespace: kube-system
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: remora:volume-scheduler
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:volume-scheduler
subjects:
- kind: ServiceAccount
  name: kube-scheduler
  namespace: kube-system
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: kube-scheduler
  namespace: kube-system
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kube-scheduler
  namespace: kube-system
  labels:
    tier: control-plane
    k8s-app: kube-scheduler
spec:
  replicas: 2
  selector:
    matchLabels:
      tier: control-plane
      k8s-app: kube-scheduler
  template:
    metadata:
      labels:
        tier: control-plane
        k8s-app: kube-scheduler
      annotations:
        scheduler.alpha.kubernetes.io/critical-pod: ''
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: tier
                  operator: In
                  values:
                  - control-plane
                - key: k8s-app
                  operator: In
                  values:
                  - kube-scheduler
              topologyKey: kubernetes.io/hostname
      containers:
      - name: kube-scheduler
        resources:
          requests:
            cpu: 100m
        image: ${KUBE_HYPERKUBE_IMAGE_REPO}:${KUBE_VERSION}
        command:
        - ./hyperkube
        - kube-scheduler
        - --leader-elect=true
        - --v=${KUBE_LOG_LEVEL:-"2"}
        livenessProbe:
          httpGet:
            path: /healthz
            port: 10251  # Note: Using default port. Update if --port option is set differently.
          initialDelaySeconds: 15
          timeoutSeconds: 15
      priorityClassName: system-cluster-critical
      nodeSelector:
        node-role.kubernetes.io/master: ""
      securityContext:
        runAsNonRoot: true
        runAsUser: 65534
      serviceAccountName: kube-scheduler
      tolerations:
      - key: CriticalAddonsOnly
        operator: Exists
      - key: node-role.kubernetes.io/master
        operator: Exists
        effect: NoSchedule

EOF
