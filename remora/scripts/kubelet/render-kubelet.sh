#!/usr/bin/env bash

set -eu
export LC_ALL=C

KUBE_IS_MASTER=${KUBE_IS_MASTER:-'0'}
NODE_IP=$1

KUBELET_NODE_LABELS=''
KUBELET_REGISTER_WITH_TAINTS=''
if [[ ${KUBE_IS_MASTER} == '1' ]]; then
  KUBELET_NODE_LABELS='--node-labels=node-role.kubernetes.io/master'
  KUBELET_REGISTER_WITH_TAINTS='--register-with-taints=node-role.kubernetes.io/master=:NoSchedule'
fi

KUBELET_SERVICE=${KUBELET_ASSETS_DIR}/kubelet.service
cat << EOF > ${KUBELET_SERVICE}
[Unit]
Description=Kubelet Container
After=${KUBE_SYSTEMD_DOCKER_SERVICE_NAME}
Requires=${KUBE_SYSTEMD_DOCKER_SERVICE_NAME}

[Service]
TimeoutStartSec=0
Restart=always
ExecReload=${DOCKER_PATH} restart kubelet
ExecStartPre=/bin/mkdir -p /etc/kubernetes/manifests
ExecStartPre=/bin/mkdir -p /opt/cni/bin
ExecStartPre=/bin/mkdir -p /etc/kubernetes/cni/net.d
ExecStartPre=/bin/mkdir -p /etc/kubernetes/checkpoint-secrets
ExecStartPre=/bin/mkdir -p /etc/kubernetes/inactive-manifests
ExecStartPre=/bin/mkdir -p ${KUBE_VOLUME_PLUGIN_DIR}
ExecStartPre=-${DOCKER_PATH} stop kubelet
ExecStartPre=-${DOCKER_PATH} rm kubelet
ExecStartPre=${DOCKER_PATH} pull ${KUBE_HYPERKUBE_IMAGE_REPO}:${KUBE_VERSION}
ExecStartPre=${DOCKER_PATH} run \\
    --rm -v \\
    /opt/cni/bin:/cnibindir \\
    --privileged=true \\
    ${KUBE_HYPERKUBE_IMAGE_REPO}:${KUBE_VERSION} \\
        /bin/cp -r /opt/cni/bin/. /cnibindir/
ExecStart=${DOCKER_PATH} run \\
    --name=kubelet \\
    --volume=/:/rootfs:ro \\
    --volume=/sys:/sys:ro \\
    --volume=/dev:/dev \\
    --volume=/var/lib/docker/:/var/lib/docker:rw \\
    --volume=/var/lib/kubelet/:/var/lib/kubelet:shared \\
    --volume=/var/run:/var/run:rw \\
    --volume=/etc/kubernetes:/etc/kubernetes:ro \\
    --volume=/etc/cni/net.d:/etc/cni/net.d:ro \\
    --volume=/opt/cni/bin:/opt/cni/bin:ro \\
    --volume=/run/systemd/resolve:/run/systemd/resolve:ro \\
    --volume=${KUBE_VOLUME_PLUGIN_DIR}:${KUBE_VOLUME_PLUGIN_DIR}:ro \\
    --net=host \\
    --pid=host \\
    --privileged=true \\
    --restart=on-failure:5 \\
    ${KUBE_HYPERKUBE_IMAGE_REPO}:${KUBE_VERSION} \\
    /hyperkube kubelet \\
        --kubeconfig=/etc/kubernetes/kubelet.yaml \\
        --config=/var/lib/kubelet/config.yaml \\
        --cni-bin-dir=/opt/cni/bin \\
        --cni-conf-dir=/etc/cni/net.d \\
        --network-plugin=${KUBE_NETWORK_PLUGIN} \\
        --hostname-override=${NODE_IP} \\
        --volume-plugin-dir=${KUBE_VOLUME_PLUGIN_DIR} \\
        ${KUBELET_NODE_LABELS} \\
        ${KUBELET_REGISTER_WITH_TAINTS} \\
        --v=${KUBE_LOG_LEVEL:-"2"}

[Install]
WantedBy=multi-user.target
EOF
