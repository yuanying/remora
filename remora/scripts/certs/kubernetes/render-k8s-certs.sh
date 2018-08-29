#!/usr/bin/env bash

set -eu
export LC_ALL=C


ROOT=$(dirname "${BASH_SOURCE}")

export CA_KEY=${KUBE_CA_KEY}
export CA_CERT=${KUBE_CA_CERT}
export CA_SERIAL=${KUBE_CA_SERIAL}

LOCAL_KUBE_CERTS_DIR=${LOCAL_KUBE_CERTS_DIR:-"${LOCAL_CERTS_DIR}/kubernetes"}
mkdir -p ${LOCAL_KUBE_CERTS_DIR}

source ${ROOT}/render-ca.sh
source ${ROOT}/render-keypair-sa.sh
source ${ROOT}/render-admin-cert.sh
source ${ROOT}/render-kubelet-client-cert.sh
source ${ROOT}/render-server-cert.sh
