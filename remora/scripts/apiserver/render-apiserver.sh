#!/usr/bin/env bash

set -eu
export LC_ALL=C

if [[ ${ETCD_SELFHOSTED} == 'true' ]]; then
  ETCD_SERVERS="https://${ETCD_CLUSTER_IP}:2379"
fi

KUBE_TEMPLATE=${LOCAL_MANIFESTS_DIR}/kube-apiserver.yaml
SERVER_CERT=$(cat ${KUBE_APISERVER_CERT} | base64 | tr -d '\n')
SERVER_KEY=$(cat ${KUBE_APISERVER_KEY} | base64 | tr -d '\n')
CA=$(cat ${KUBE_CA_CERT} | base64 | tr -d '\n')
FP_CA=$(cat ${KUBE_FRONT_PROXY_CA_CERT} | base64 | tr -d '\n')
ETCD_CLIENT_CA=$(cat ${ETCD_CA_CERT} | base64 | tr -d '\n')
ETCD_CLIENT_CERT=$(cat ${ETCD_CLIENT_CERT} | base64 | tr -d '\n')
ETCD_CLIENT_KEY=$(cat ${ETCD_CLIENT_KEY} | base64 | tr -d '\n')
SA_PUB_KEY=$(cat ${KUBE_SA_PUB_KEY} | base64 | tr -d '\n')
KUBELET_CLIENT_CERT=$(cat ${KUBE_KUBELET_CLIENT_CERT} | base64 | tr -d '\n')
KUBELET_CLIENT_KEY=$(cat ${KUBE_KUBELET_CLIENT_KEY} | base64 | tr -d '\n')
FP_CLIENT_CERT=$(cat ${KUBE_FRONT_PROXY_CLIENT_CERT} | base64 | tr -d '\n')
FP_CLIENT_KEY=$(cat ${KUBE_FRONT_PROXY_CLIENT_KEY} | base64 | tr -d '\n')

cat << EOF > $KUBE_TEMPLATE
---
apiVersion: v1
data:
  apiserver.crt: ${SERVER_CERT}
  apiserver.key: ${SERVER_KEY}
  ca.crt: ${CA}
  front-proxy-ca.crt: ${FP_CA}
  etcd-client-ca.crt: ${ETCD_CLIENT_CA}
  etcd-client.crt: ${ETCD_CLIENT_CERT}
  etcd-client.key: ${ETCD_CLIENT_KEY}
  service-account.pub: ${SA_PUB_KEY}
  kubelet-client.crt: ${KUBELET_CLIENT_CERT}
  kubelet-client.key: ${KUBELET_CLIENT_KEY}
  front-proxy-client.crt: ${FP_CLIENT_CERT}
  front-proxy-client.key: ${FP_CLIENT_KEY}
kind: Secret
metadata:
  name: kube-apiserver
  namespace: kube-system
type: Opaque
---
apiVersion: "apps/v1"
kind: DaemonSet
metadata:
  name: kube-apiserver
  namespace: kube-system
  labels:
    tier: control-plane
    k8s-app: kube-apiserver
spec:
  selector:
    matchLabels:
      tier: control-plane
      k8s-app: kube-apiserver
  template:
    metadata:
      labels:
        tier: control-plane
        k8s-app: kube-apiserver
      annotations:
        checkpointer.alpha.coreos.com/checkpoint: "true"
        scheduler.alpha.kubernetes.io/critical-pod: ''
    spec:
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
        - apiserver
        - --authorization-mode=Node,RBAC
        - --advertise-address=\$(POD_IP)
        - --allow-privileged=true
        - --bind-address=0.0.0.0
        - --client-ca-file=/etc/kubernetes/secrets/ca.crt
        - --disable-admission-plugins=${KUBE_DISABLE_ADMISSION_PLUGINS}
        - --enable-admission-plugins=${KUBE_ENABLE_ADMISSION_PLUGINS}
        - --enable-bootstrap-token-auth=true
        - --etcd-cafile=/etc/kubernetes/secrets/etcd-client-ca.crt
        - --etcd-certfile=/etc/kubernetes/secrets/etcd-client.crt
        - --etcd-keyfile=/etc/kubernetes/secrets/etcd-client.key
        - --etcd-servers=${ETCD_SERVERS}
        - --insecure-port=0
        - --kubelet-certificate-authority=/etc/kubernetes/secrets/ca.crt
        - --kubelet-client-certificate=/etc/kubernetes/secrets/kubelet-client.crt
        - --kubelet-client-key=/etc/kubernetes/secrets/kubelet-client.key
        - --proxy-client-cert-file=/etc/kubernetes/secrets/front-proxy-client.crt
        - --proxy-client-key-file=/etc/kubernetes/secrets/front-proxy-client.key
        - --requestheader-client-ca-file=/etc/kubernetes/secrets/front-proxy-ca.crt
        - --requestheader-allowed-names=aggregator
        - --requestheader-extra-headers-prefix=X-Remote-Extra-
        - --requestheader-group-headers=X-Remote-Group
        - --requestheader-username-headers=X-Remote-User
        - --secure-port=${KUBE_INTERNAL_PORT}
        - --service-account-key-file=/etc/kubernetes/secrets/service-account.pub
        - --service-cluster-ip-range=${KUBE_SERVICE_IP_RANGE}
        - --storage-backend=${KUBE_STORAGE_BACKEND}
        - --tls-cert-file=/etc/kubernetes/secrets/apiserver.crt
        - --tls-private-key-file=/etc/kubernetes/secrets/apiserver.key
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
        - mountPath: /usr/local/share/ca-certificates
          name: usr-local-share-ca-certificates
          readOnly: true
        - mountPath: /etc/kubernetes/secrets
          name: secrets
          readOnly: true
        - mountPath: /var/lock
          name: var-lock
          readOnly: false
      hostNetwork: true
      priorityClassName: system-cluster-critical
      nodeSelector:
        node-role.kubernetes.io/master: ""
      tolerations:
      - key: CriticalAddonsOnly
        operator: Exists
      - key: node-role.kubernetes.io/master
        operator: Exists
        effect: NoSchedule
      volumes:
      - hostPath:
          path: /etc/ssl/certs
          type: DirectoryOrCreate
        name: ca-certs
      - hostPath:
          path: /usr/share/ca-certificates
          type: DirectoryOrCreate
        name: usr-share-ca-certificates
      - hostPath:
          path: /usr/local/share/ca-certificates
          type: DirectoryOrCreate
        name: usr-local-share-ca-certificates
      - hostPath:
          path: /etc/ca-certificates
          type: DirectoryOrCreate
        name: etc-ca-certificates
      - name: secrets
        secret:
          secretName: kube-apiserver
      - name: var-lock
        hostPath:
          path: /var/lock
  updateStrategy:
    rollingUpdate:
      maxUnavailable: 1
    type: RollingUpdate

EOF
