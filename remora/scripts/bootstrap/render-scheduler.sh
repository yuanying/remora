#!/usr/bin/env bash

set -eu
export LC_ALL=C

export KUBE_SCHEDULER_TEMPLATE=${KUBE_BOOTSTRAP_MANIFESTS_DIR}/kube-scheduler.bootstrap.yaml
mkdir -p $(dirname $KUBE_SCHEDULER_TEMPLATE)
cat << EOF > $KUBE_SCHEDULER_TEMPLATE
---
apiVersion: v1
kind: Pod
metadata:
  name: bootstrap-kube-scheduler
  namespace: kube-system
spec:
  containers:
  - name: kube-scheduler
    image: ${KUBE_HYPERKUBE_IMAGE_REPO}:${KUBE_VERSION}
    command:
    - ./hyperkube
    - kube-scheduler
    - --kubeconfig=/etc/kubernetes/bootstrap/kubeconfig-bootstrap
    - --leader-elect=true
    - --v=${KUBE_LOG_LEVEL:-"2"}
    volumeMounts:
    - name: kubernetes
      mountPath: /etc/kubernetes
      readOnly: true
  hostNetwork: true
  volumes:
  - name: kubernetes
    hostPath:
      path: /etc/kubernetes
EOF
