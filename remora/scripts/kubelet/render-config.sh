#!/usr/bin/env bash

set -eu
export LC_ALL=C

KUBE_KUBE_RESERVED_CGROUP=${KUBE_KUBE_RESERVED_CGROUP:-'0'}
KUBE_SYSTEM_RESERVED_CGROUP=${KUBE_SYSTEM_RESERVED_CGROUP:-'0'}

KUBELET_KUBE_RESERVED_OPTS=''
KUBELET_KUBE_RESERVED_CGROUP_OPTS=''
if [[ ${KUBE_KUBE_RESERVED_CGROUP} != '0' ]]; then
  KUBELET_KUBE_RESERVED_OPTS="kubeReserved: ${KUBE_KUBE_RESERVED}"
  KUBELET_KUBE_RESERVED_CGROUP_OPTS="kubeReservedCgroup: ${KUBE_KUBE_RESERVED_CGROUP}"
fi
KUBELET_SYSTEM_RESERVED_OPTS=''
KUBELET_SYSTEM_RESERVED_CGROUP_OPTS=''
if [[ ${KUBE_SYSTEM_RESERVED_CGROUP} != '0' ]]; then
  KUBELET_SYSTEM_RESERVED_OPTS="systemReservedCgroup: ${KUBE_SYSTEM_RESERVED}"
  KUBELET_SYSTEM_RESERVED_CGROUP_OPTS="systemReservedCgroup: ${KUBE_SYSTEM_RESERVED_CGROUP}"
fi

CONFIG_TEMPLATE=${KUBELET_ASSETS_DIR}/config.yaml

mkdir -p $(dirname $CONFIG_TEMPLATE)
cat << EOF > $CONFIG_TEMPLATE
address: 0.0.0.0
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    cacheTTL: 2m0s
    enabled: true
  x509:
    clientCAFile: /etc/kubernetes/ca.crt
authorization:
  mode: Webhook
  webhook:
    cacheAuthorizedTTL: 5m0s
    cacheUnauthorizedTTL: 30s
cgroupDriver: ${KUBE_CGROUP_DRIVER:-""}
cgroupsPerQOS: true
clusterDNS:
- ${KUBE_CLUSTER_DNS_IP}
clusterDomain: cluster.local
containerLogMaxFiles: 5
containerLogMaxSize: 10Mi
contentType: application/vnd.kubernetes.protobuf
cpuCFSQuota: true
cpuManagerPolicy: none
cpuManagerReconcilePeriod: 10s
enableControllerAttachDetach: true
enableDebuggingHandlers: true
enforceNodeAllocatable:
- pods
eventBurst: 10
eventRecordQPS: 5
evictionHard:
  imagefs.available: 15%
  memory.available: 100Mi
  nodefs.available: 10%
  nodefs.inodesFree: 5%
evictionPressureTransitionPeriod: 5m0s
failSwapOn: true
fileCheckFrequency: 20s
hairpinMode: promiscuous-bridge
healthzBindAddress: 127.0.0.1
healthzPort: 10248
httpCheckFrequency: 20s
imageGCHighThresholdPercent: 85
imageGCLowThresholdPercent: 80
imageMinimumGCAge: 2m0s
iptablesDropBit: 15
iptablesMasqueradeBit: 14
kind: KubeletConfiguration
kubeAPIBurst: 10
kubeAPIQPS: 5
makeIPTablesUtilChains: true
maxOpenFiles: 1000000
maxPods: 110
nodeStatusUpdateFrequency: 10s
oomScoreAdj: -999
podPidsLimit: -1
port: 10250
registryBurst: 10
registryPullQPS: 5
resolvConf: /run/systemd/resolve/resolv.conf
rotateCertificates: true
runtimeRequestTimeout: 2m0s
serializeImagePulls: true
staticPodPath: /etc/kubernetes/manifests
streamingConnectionIdleTimeout: 4h0m0s
syncFrequency: 1m0s
volumeStatsAggPeriod: 1m0s
tlsCertFile: /etc/kubernetes/kubelet.crt
tlsPrivateKeyFile: /etc/kubernetes/kubelet.key
${KUBELET_KUBE_RESERVED_OPTS}
${KUBELET_KUBE_RESERVED_CGROUP_OPTS}
${KUBELET_SYSTEM_RESERVED_OPTS}
${KUBELET_SYSTEM_RESERVED_CGROUP_OPTS}
EOF