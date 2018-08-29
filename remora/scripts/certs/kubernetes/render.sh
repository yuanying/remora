#!/usr/bin/env bash

set -eu
export LC_ALL=C


ROOT=$(dirname "${BASH_SOURCE}")

LOCAL_KUBE_CERTS_DIR=${LOCAL_KUBE_CERTS_DIR:-"${LOCAL_CERTS_DIR}/kubernetes"}
mkdir -p ${LOCAL_KUBE_CERTS_DIR}

bash ${ROOT}/render-k8s-certs.sh
bash ${ROOT}/render-front-proxy-certs.sh
