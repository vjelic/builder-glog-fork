#!/usr/bin/env bash

set -eou pipefail

TOPDIR=$(git rev-parse --show-toplevel)

GPU_ARCH_TYPE=cpu conda/build_docker.sh

for CUDA_VERSION in 11.7 11.6 11.5 11.3 10.2; do
  GPU_ARCH_TYPE=cuda GPU_ARCH_VERSION="${CUDA_VERSION}" conda/build_docker.sh
done

for ROCM_VERSION in 5.1.1 5.2 5.3; do
    GPU_ARCH_TYPE=rocm GPU_ARCH_VERSION="${ROCM_VERSION}" conda/build_docker.sh
done
