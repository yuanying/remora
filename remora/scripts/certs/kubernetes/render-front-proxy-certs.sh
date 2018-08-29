#!/usr/bin/env bash

set -eu
export LC_ALL=C


ROOT=$(dirname "${BASH_SOURCE}")

export CA_KEY=${KUBE_FRONT_PROXY_CA_KEY}
export CA_CERT=${KUBE_FRONT_PROXY_CA_CERT}
export CA_SERIAL=${KUBE_FRONT_PROXY_CA_SERIAL}

export CLIENT_KEY=${KUBE_FRONT_PROXY_CLIENT_KEY}
export CLIENT_CERT_REQ=${KUBE_FRONT_PROXY_CLIENT_CERT_REQ}
export CLIENT_CERT=${KUBE_FRONT_PROXY_CLIENT_CERT}

LOCAL_KUBE_CERTS_DIR=${LOCAL_KUBE_CERTS_DIR:-"${LOCAL_CERTS_DIR}/kubernetes"}
mkdir -p ${LOCAL_KUBE_CERTS_DIR}

source ${ROOT}/render-ca.sh
source ${ROOT}/../gen-cert-client.sh prefix "/CN=aggregator-client"

