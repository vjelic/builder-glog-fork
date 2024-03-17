ARG ROCM_VERSION=5.7
ARG BASE_CUDA_VERSION=10.2
ARG BASE_TARGET=cuda${BASE_CUDA_VERSION}
ARG GPU_IMAGE=centos:7
FROM ${GPU_IMAGE} as base

ENV LC_ALL en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.UTF-8

ARG DEVTOOLSET_VERSION=9
RUN yum update -y
RUN yum install -y wget curl perl util-linux xz bzip2 git patch which unzip
# Just add everything as a safe.directory for git since these will be used in multiple places with git
RUN git config --global --add safe.directory '*'
RUN yum install -y yum-utils centos-release-scl
RUN yum-config-manager --enable rhel-server-rhscl-7-rpms
RUN yum install -y devtoolset-${DEVTOOLSET_VERSION}-gcc devtoolset-${DEVTOOLSET_VERSION}-gcc-c++ devtoolset-${DEVTOOLSET_VERSION}-gcc-gfortran devtoolset-${DEVTOOLSET_VERSION}-binutils

ENV PATH=/opt/rh/devtoolset-${DEVTOOLSET_VERSION}/root/usr/bin:$PATH
ENV LD_LIBRARY_PATH=/opt/rh/devtoolset-${DEVTOOLSET_VERSION}/root/usr/lib64:/opt/rh/devtoolset-${DEVTOOLSET_VERSION}/root/usr/lib:$LD_LIBRARY_PATH

RUN yum install -y autoconf aclocal automake make sudo

FROM base as patchelf
# Install patchelf
ADD ./common/install_patchelf.sh install_patchelf.sh
RUN bash ./install_patchelf.sh && rm install_patchelf.sh && cp $(which patchelf) /patchelf

FROM base as openssl
# Install openssl
ADD ./common/install_openssl.sh install_openssl.sh
RUN bash ./install_openssl.sh && rm install_openssl.sh

FROM base as conda
# Install Anaconda
ADD ./common/install_conda.sh install_conda.sh
RUN bash ./install_conda.sh && rm install_conda.sh

FROM base as cpu_base
# EPEL for cmake
RUN wget http://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm && \
    rpm -ivh epel-release-latest-7.noarch.rpm && \
    rm -f epel-release-latest-7.noarch.rpm
# cmake
RUN yum install -y cmake3 && \
    ln -s /usr/bin/cmake3 /usr/bin/cmake

RUN rm -rf /usr/local/cuda-*

# Install CUDA
FROM cpu_base as cuda
ENV CUDA_HOME=/usr/local/cuda-${CUDA_VERSION}
# Preserve CUDA_VERSION for the builds
ENV CUDA_VERSION=${CUDA_VERSION}
# Make things in our path by default
ENV PATH=/usr/local/cuda-${CUDA_VERSION}/bin:$PATH
ADD ./common/install_cuda.sh install_cuda.sh

FROM cuda as cuda11.8
RUN bash ./install_cuda.sh 11.8
ENV DESIRED_CUDA=11.8

FROM cuda as cuda12.1
RUN bash ./install_cuda.sh 12.1
ENV DESIRED_CUDA=12.1

FROM cuda as cuda12.4
RUN bash ./install_cuda.sh 12.4
ENV DESIRED_CUDA=12.4

# Install MNIST test data
FROM base as mnist
ADD ./common/install_mnist.sh install_mnist.sh
RUN bash ./install_mnist.sh

FROM cpu_base as all_cuda_base
COPY --from=cuda11.8  /usr/local/cuda-11.8 /usr/local/cuda-11.8
COPY --from=cuda12.1  /usr/local/cuda-12.1 /usr/local/cuda-12.1
COPY --from=cuda12.4  /usr/local/cuda-12.4 /usr/local/cuda-12.4

FROM base as rocm_base
ARG ROCM_VERSION=5.2
ARG PYTORCH_ROCM_ARCH
ENV PYTORCH_ROCM_ARCH ${PYTORCH_ROCM_ARCH}
# Install ROCm
# ADD ./common/install_rocm.sh install_rocm.sh
# RUN ROCM_VERSION=${ROCM_VERSION} bash ./install_rocm.sh && rm install_rocm.sh
# ADD ./common/install_rocm_drm.sh install_rocm_drm.sh
# RUN bash ./install_rocm_drm.sh && rm install_rocm_drm.sh
# cmake is already installed inside the rocm base image, but both 2 and 3 exist
# cmake3 is needed for the later MIOpen custom build, so that step is last.
RUN yum install -y cmake3 && \
    rm -f /usr/bin/cmake && \
    ln -s /usr/bin/cmake3 /usr/bin/cmake
# ADD ./common/install_miopen.sh install_miopen.sh
# RUN bash ./install_miopen.sh ${ROCM_VERSION} && rm install_miopen.sh


FROM ${BASE_TARGET} as final
COPY --from=openssl            /opt/openssl           /opt/openssl
COPY --from=patchelf           /patchelf              /usr/local/bin/patchelf
COPY --from=conda              /opt/conda             /opt/conda
ADD  ./java/jni.h /usr/local/include/jni.h
ENV  PATH /opt/conda/bin:$PATH
COPY --from=mnist  /usr/local/mnist /usr/local/mnist
RUN rm -rf /usr/local/cuda
RUN chmod o+rw /usr/local
RUN touch /.condarc && \
    chmod o+rw /.condarc && \
    chmod -R o+rw /opt/conda
