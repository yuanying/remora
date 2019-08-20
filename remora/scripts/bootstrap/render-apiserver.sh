#!/usr/bin/env bash

set -eu
export LC_ALL=C

if [[ ${ETCD_SELFHOSTED} == 'true' ]]; then
  ETCD_SERVERS="https://${ETCD_CLUSTER_IP}:2379,https://127.0.0.1:12379"
fi

export KUBE_API_TEMPLATE=${KUBE_BOOTSTRAP_MANIFESTS_DIR}/kube-apiserver.bootstrap.yaml
mkdir -p $(dirname $KUBE_API_TEMPLATE)
cat << EOF > $KUBE_API_TEMPLATE
apiVersion: v1
kind: Pod
metadata:
  name: bootstrap-kube-apiserver
  namespace: kube-system
spec:
  hostNetwork: true
  containers:
  - name: kube-apiserver
    resources:
      requests:
        cpu: 250m
    image: ${KUBE_HYPERKUBE_IMAGE_REPO}:${KUBE_VERSION}
    command:
    - /usr/bin/flock
    - /var/lock/api-server.lock
    - /hyperkube
    - kube-apiserver
    - --authorization-mode=Node,RBAC
    - --advertise-address=\$(POD_IP)
    - --allow-privileged
    - --bind-address=0.0.0.0
    - --client-ca-file=/etc/kubernetes/secrets/kubernetes/ca.crt
    - --disable-admission-plugins=${KUBE_DISABLE_ADMISSION_PLUGINS}
    - --enable-admission-plugins=${KUBE_ENABLE_ADMISSION_PLUGINS}
    - --enable-bootstrap-token-auth=true
    - --etcd-cafile=/etc/kubernetes/secrets/etcd/ca.crt
    - --etcd-certfile=/etc/kubernetes/secrets/etcd/etcd-client.crt
    - --etcd-keyfile=/etc/kubernetes/secrets/etcd/etcd-client.key
    - --etcd-servers=${ETCD_SERVERS}
    - --kubelet-certificate-authority=/etc/kubernetes/secrets/kubernetes/ca.crt
    - --kubelet-client-certificate=/etc/kubernetes/secrets/kubernetes/kubelet-client.crt
    - --kubelet-client-key=/etc/kubernetes/secrets/kubernetes/kubelet-client.key
    - --secure-port=${KUBE_INTERNAL_PORT}
    - --service-account-key-file=/etc/kubernetes/secrets/kubernetes/sa.pub
    - --service-cluster-ip-range=${KUBE_SERVICE_IP_RANGE}
    - --storage-backend=${KUBE_STORAGE_BACKEND}
    - --tls-cert-file=/etc/kubernetes/secrets/kubernetes/apiserver.crt
    - --tls-private-key-file=/etc/kubernetes/secrets/kubernetes/apiserver.key
    - --kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname
    - --v=${KUBE_LOG_LEVEL:-"2"}
    env:
    - name: POD_IP
      valueFrom:
        fieldRef:
          fieldPath: status.podIP
    volumeMounts:
    - mountPath: /etc/ca-certificates
      name: etc-ca-certificates
      readOnly: true
    - mountPath: /etc/ssl/certs
      name: ca-certs
      readOnly: true
    - mountPath: /usr/share/ca-certificates
      name: usr-share-ca-certificates
      readOnly: true
    - mountPath: /etc/kubernetes/secrets
      name: secrets
      readOnly: true
    - mountPath: /var/lock
      name: var-lock
      readOnly: false
  volumes:
  - name: secrets
    hostPath:
      path: /etc/kubernetes/bootstrap/secrets
  - hostPath:
      path: /etc/ssl/certs
      type: DirectoryOrCreate
    name: ca-certs
  - hostPath:
      path: /usr/share/ca-certificates
      type: DirectoryOrCreate
    name: usr-share-ca-certificates
  - hostPath:
      path: /etc/ca-certificates
      type: DirectoryOrCreate
    name: etc-ca-certificates
  - name: var-lock
    hostPath:
      path: /var/lock
EOF
