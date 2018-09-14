#!/usr/bin/env bash

set -eu
export LC_ALL=C

ROOT=$(dirname "${BASH_SOURCE}")

export LOCAL_MANIFESTS_DIR=${KUBE_MANIFESTS_DIR}
mkdir -p ${LOCAL_MANIFESTS_DIR}
echo ${LOCAL_MANIFESTS_DIR}

source ${ROOT}/render-coredns.sh
