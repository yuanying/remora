#!/usr/bin/env bash

set -eu
export LC_ALL=C

CONFIGURE_CLOUD_ROUTES=false

export KUBE_CM_TEMPLATE=${KUBE_BOOTSTRAP_MANIFESTS_DIR}/kube-controller-manager.bootstrap.yaml
mkdir -p $(dirname $KUBE_CM_TEMPLATE)
cat << EOF > $KUBE_CM_TEMPLATE
---
apiVersion: v1
kind: Pod
metadata:
  name: bootstrap-kube-controller-manager
  namespace: kube-system
spec:
  containers:
  - name: kube-controller-manager
    image: ${KUBE_HYPERKUBE_IMAGE_REPO}:${KUBE_VERSION}
    command:
    - ./hyperkube
    - controller-manager
    - --allocate-node-cidrs=true
    - --cluster-cidr=${KUBE_CLUSTER_CIDR}
    - --cluster-signing-cert-file=/etc/kubernetes/bootstrap/secrets/kubernetes/ca.crt
    - --cluster-signing-key-file=/etc/kubernetes/bootstrap/secrets/kubernetes/ca.key
    - --controllers=*,bootstrapsigner,tokencleaner
    - --kubeconfig=/etc/kubernetes/bootstrap/kubeconfig-bootstrap
    - --leader-elect=true
    - --node-cidr-mask-size=${KUBE_NODE_CIDR_MASK_SIZE}
    - --root-ca-file=/etc/kubernetes/bootstrap/secrets/kubernetes/ca.crt
    - --service-account-private-key-file=/etc/kubernetes/bootstrap/secrets/kubernetes/sa.key
    - --use-service-account-credentials=true
    - --v=${KUBE_LOG_LEVEL:-"2"}
    volumeMounts:
    - name: var-run-kubernetes
      mountPath: /var/run/kubernetes
    - name: kubernetes
      mountPath: /etc/kubernetes
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
  hostNetwork: true
  volumes:
  - name: var-run-kubernetes
    emptyDir: {}
  - name: kubernetes
    hostPath:
      path: /etc/kubernetes
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
EOF
