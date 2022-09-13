#!/usr/bin/env bash

set -eou pipefail

export DOCKER_BUILDKIT=1
TOPDIR=$(git rev-parse --show-toplevel)

GPU_ARCH_TYPE=${GPU_ARCH_TYPE:-cpu}
GPU_ARCH_VERSION=${GPU_ARCH_VERSION:-}

case ${GPU_ARCH_TYPE} in
  cpu)
    BASE_TARGET=cpu_base
    DOCKER_TAG=cpu
    ;;
  cuda)
    if [[ "$GPU_ARCH_VERSION" == all ]]; then
      BASE_TARGET=all_cuda_base
      DOCKER_TAG=all_cuda
    else
      BASE_TARGET=cuda${GPU_ARCH_VERSION}_base
      DOCKER_TAG=cuda${GPU_ARCH_VERSION}
    fi
    DEVTOOLSET_VERSION="9"
    if [[ ${GPU_ARCH_VERSION:0:2} == "10" ]]; then
      DEVTOOLSET_VERSION="7"
    fi
    GPU_IMAGE=nvidia/cuda:${GPU_ARCH_VERSION}-devel-centos7
    DOCKER_GPU_BUILD_ARG="--build-arg BASE_CUDA_VERSION=${GPU_ARCH_VERSION} --build-arg DEVTOOLSET_VERSION=${DEVTOOLSET_VERSION}"
    ;;
  rocm)
    BASE_TARGET=rocm_final
    DOCKER_TAG=rocm${GPU_ARCH_VERSION}
    GPU_IMAGE=rocm/dev-centos-7:${GPU_ARCH_VERSION}
    DOCKER_GPU_BUILD_ARG="--build-arg ROCM_VERSION=${GPU_ARCH_VERSION}"
    ;;
  *)
    echo "ERROR: Unrecognized GPU_ARCH_TYPE: ${GPU_ARCH_TYPE}"
    exit 1
    ;;
esac

(
  set -x
  docker build \
    --target final \
    ${DOCKER_GPU_BUILD_ARG} \
    --build-arg "BASE_TARGET=${BASE_TARGET}" \
    --build-arg "GPU_IMAGE=${GPU_IMAGE}" \
    -t "pytorch/conda-builder:${DOCKER_TAG}" \
    -f "${TOPDIR}/conda/Dockerfile" \
    ${TOPDIR}
)

DOCKER_IMAGE="pytorch/conda-builder:${DOCKER_TAG}"
GITHUB_REF=${GITHUB_REF:-$(git symbolic-ref -q HEAD || git describe --tags --exact-match)}
GIT_BRANCH_NAME=${GITHUB_REF##*/}
GIT_COMMIT_SHA=${GITHUB_SHA:-$(git rev-parse HEAD)}
DOCKER_IMAGE_BRANCH_TAG=${DOCKER_IMAGE}-${GIT_BRANCH_NAME}
DOCKER_IMAGE_SHA_TAG=${DOCKER_IMAGE}-${GIT_COMMIT_SHA}

if [[ "${DOCKER_TAG}" =~ ^cuda* ]]; then
  # Meant for legacy scripts since they only do the version without the "."
  # TODO: Eventually remove this
  (
    set -x
    docker tag ${DOCKER_IMAGE} "pytorch/conda-builder:cuda${CUDA_VERSION/./}"
  )
fi

if [[ -n ${GITHUB_REF} ]]; then
    docker tag ${DOCKER_IMAGE} ${DOCKER_IMAGE_BRANCH_TAG}
    docker tag ${DOCKER_IMAGE} ${DOCKER_IMAGE_SHA_TAG}
fi

if [[ "${WITH_PUSH:-}" == true ]]; then
  (
    set -x
    docker push "${DOCKER_IMAGE}"
    if [[ -n ${GITHUB_REF} ]]; then
        docker push "${DOCKER_IMAGE_BRANCH_TAG}"
        docker push "${DOCKER_IMAGE_SHA_TAG}"
    fi
    if [[ "${DOCKER_TAG}" =~ ^cuda* ]]; then
      docker push "pytorch/conda-builder:cuda${CUDA_VERSION/./}"
    fi
  )
fi
