#!/usr/bin/env bash

set -eu
export LC_ALL=C

export NODE_IP=${1:-${NODE_IP}}

TEMPLATE=${KUBE_BOOTSTRAP_TEMP_DIR}/haproxy.cfg
cat << EOF > $TEMPLATE
global
        quiet
        maxconn 2048
defaults
        mode    tcp
        balance leastconn
        timeout client      30m
        timeout server      30m
        timeout connect     3000ms
        retries 3
frontend kube_api
        bind 0.0.0.0:${KUBE_PORT}
        default_backend kube_api_backend
backend kube_api_backend
        option tcp-check
        server bootstrap_api ${NODE_IP}:${KUBE_INTERNAL_PORT} check
EOF
chmod 664 ${TEMPLATE}

TEMPLATE=${KUBE_BOOTSTRAP_TEMP_DIR}/keepalived.cfg
mkdir -p $(dirname $TEMPLATE)
cat << EOF > $TEMPLATE
vrrp_instance VI {
  state BACKUP
  interface __NET_IFACE__
  track_interface {
    __NET_IFACE__
  }
  garp_master_delay 5
  virtual_router_id ${HAPROXY_KEEPALIVED_VRID:-"1"}
  priority 101
  nopreempt
  advert_int 1
EOF
if [[ ${HAPROXY_KEEPALIVED_USE_UNICAST} == 'true' ]]; then
  echo "  unicast_peer {" >> ${TEMPLATE}
  for address in ${KUBE_MASTERS}; do
      echo "    ${address}" >> ${TEMPLATE}
  done
  echo "  }" >> ${TEMPLATE}
fi
cat << EOF >> $TEMPLATE
  authentication {
    auth_type PASS
    auth_pass ${HAPROXY_KEEPALIVED_AUTH_PASSWORD:-'himitsu'}
  }
  virtual_ipaddress {
    ${KUBE_PUBLIC_SERVICE_IP}
  }
}
EOF
chmod 664 $TEMPLATE

TEMPLATE=${KUBE_BOOTSTRAP_MANIFESTS_DIR}/keepalived.bootstrap.yaml
cat << EOF > $TEMPLATE
apiVersion: v1
kind: Pod
metadata:
  name: bootstrap-keepalived
  namespace: kube-system
spec:
  hostNetwork: true
  containers:
  - name: bootstrap-keepalived
    image: yuanying/keepalived:v0.2.1
    securityContext:
      capabilities:
        add: ["NET_ADMIN", "NET_BROADCAST"]
    volumeMounts:
    - mountPath: /etc/keepalived/keepalived.cfg
      name: keepalived
      readOnly: false
    - mountPath: /var/lock
      name: var-lock
      readOnly: false
    command:
    - /start.sh
    - /usr/bin/flock
    - /var/lock/keepalived.lock
    - -c
    - "/usr/sbin/keepalived -f /etc/keepalived/keepalived.cfg -l -D -P -n"
    env:
    - name: POD_IP
      valueFrom:
        fieldRef:
          fieldPath: status.podIP
  - name: bootstrap-haproxy
    image: haproxy:alpine
    volumeMounts:
    - mountPath: /usr/local/etc/haproxy/haproxy.cfg
      name: haproxy
      readOnly: false
    - mountPath: /var/lock
      name: var-lock
      readOnly: false
    command:
    - /usr/bin/flock
    - /var/lock/haproxy.lock
    - -c
    - "haproxy -f /usr/local/etc/haproxy/haproxy.cfg"
  volumes:
  - hostPath:
      path: /etc/kubernetes/bootstrap/haproxy.cfg
    name: haproxy
  - hostPath:
      path: /etc/kubernetes/bootstrap/keepalived.cfg
    name: keepalived
  - name: var-lock
    hostPath:
      path: /var/lock
EOF
