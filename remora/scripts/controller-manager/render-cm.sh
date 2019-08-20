#!/usr/bin/env bash

set -eu
export LC_ALL=C

CONFIGURE_CLOUD_ROUTES=false

KUBE_TEMPLATE=${LOCAL_MANIFESTS_DIR}/kube-controller-manager.yaml

CA=$(cat ${KUBE_CA_CERT} | base64 | tr -d '\n')
CA_KEY=$(cat ${KUBE_CA_KEY} | base64 | tr -d '\n')
SA_KEY=$(cat ${KUBE_SA_KEY} | base64 | tr -d '\n')

cat << EOF > $KUBE_TEMPLATE
---
apiVersion: policy/v1beta1
kind: PodDisruptionBudget
metadata:
  name: kube-controller-manager
  namespace: kube-system
spec:
  minAvailable: 1
  selector:
    matchLabels:
      tier: control-plane
      k8s-app: kube-controller-manager
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: remora:kube-controller-manager
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:kube-controller-manager
subjects:
- kind: ServiceAccount
  name: kube-controller-manager
  namespace: kube-system
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: kube-controller-manager
  namespace: kube-system
---
apiVersion: v1
data:
  ca.crt: ${CA}
  ca.key: ${CA_KEY}
  service-account.key: ${SA_KEY}
kind: Secret
metadata:
  name: kube-controller-manager
  namespace: kube-system
type: Opaque
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kube-controller-manager
  namespace: kube-system
  labels:
    tier: control-plane
    k8s-app: kube-controller-manager
spec:
  replicas: 2
  selector:
    matchLabels:
      tier: control-plane
      k8s-app: kube-controller-manager
  template:
    metadata:
      labels:
        tier: control-plane
        k8s-app: kube-controller-manager
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
                  - kube-controller-manager
              topologyKey: kubernetes.io/hostname
      containers:
      - name: kube-controller-manager
        resources:
          requests:
            cpu: 200m
        image: ${KUBE_HYPERKUBE_IMAGE_REPO}:${KUBE_VERSION}
        command:
        - ./hyperkube
        - kube-controller-manager
        - --allocate-node-cidrs=true
        - --cluster-cidr=${KUBE_CLUSTER_CIDR}
        - --cluster-signing-cert-file=/etc/kubernetes/secrets/ca.crt
        - --cluster-signing-key-file=/etc/kubernetes/secrets/ca.key
        - --controllers=*,bootstrapsigner,tokencleaner
        - --leader-elect=true
        - --node-cidr-mask-size=${KUBE_NODE_CIDR_MASK_SIZE}
        - --root-ca-file=/etc/kubernetes/secrets/ca.crt
        - --service-account-private-key-file=/etc/kubernetes/secrets/service-account.key
        - --use-service-account-credentials=true
        - --v=${KUBE_LOG_LEVEL:-"2"}
        livenessProbe:
          httpGet:
            path: /healthz
            port: 10252  # Note: Using default port. Update if --port option is set differently.
          initialDelaySeconds: 15
          timeoutSeconds: 15
        volumeMounts:
        - name: var-run-kubernetes
          mountPath: /var/run/kubernetes
        - name: secrets
          mountPath: /etc/kubernetes/secrets
          readOnly: true
        - mountPath: /usr/libexec/kubernetes/kubelet-plugins/volume/exec
          name: flexvolume-dir
        - mountPath: /usr/share/ca-certificates
          name: usr-share-ca-certificates
          readOnly: true
        - mountPath: /etc/ca-certificates
          name: etc-ca-certificates
          readOnly: true
        - mountPath: /etc/ssl/certs
          name: ca-certs
          readOnly: true
      priorityClassName: system-cluster-critical
      nodeSelector:
        node-role.kubernetes.io/master: ""
      securityContext:
        runAsNonRoot: true
        runAsUser: 65534
      serviceAccountName: kube-controller-manager
      tolerations:
      - key: CriticalAddonsOnly
        operator: Exists
      - key: node-role.kubernetes.io/master
        operator: Exists
        effect: NoSchedule
      volumes:
      - name: var-run-kubernetes
        emptyDir: {}
      - name: secrets
        secret:
          secretName: kube-controller-manager
      - hostPath:
          path: /etc/ssl/certs
          type: DirectoryOrCreate
        name: ca-certs
      - hostPath:
          path: ${KUBE_VOLUME_PLUGIN_DIR}
          type: DirectoryOrCreate
        name: flexvolume-dir
      - hostPath:
          path: /usr/share/ca-certificates
          type: DirectoryOrCreate
        name: usr-share-ca-certificates
      - hostPath:
          path: /etc/ca-certificates
          type: DirectoryOrCreate
        name: etc-ca-certificates
      dnsPolicy: Default # Don't use cluster DNS.

EOF
