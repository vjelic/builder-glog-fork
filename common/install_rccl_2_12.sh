#!/bin/bash

# This file uninstalls RCCL and install specific RCCL 2.12 version

set -ex

# Disable SDMA by default
export HSA_ENABLE_SDMA=0

# Config the RCCL IB relaxed ordering
export NCCL_IB_PCI_RELAXED_ORDERING=1
export NCCL_NET_GDR_LEVEL=3

# clean up dependencies no longer needed for RCCL 2.12
RUN cd / && find /usr -name librccl-net.so* | xargs rm -rf

cd ~ && git clone https://github.com/ROCmSoftwarePlatform/rccl.git
cd ~/rccl && git reset --hard 8c3c8b7 && ./install.sh -id && cd build/release && make package

ID=$(grep -oP '(?<=^ID=).+' /etc/os-release | tr -d '"')
case "$ID" in
  ubuntu)
    apt purge ucx openmpi -y 
    dpkg -i *.deb
    ;;
  centos)
    yum autoremove -y ucx openmpi
    rpm -ivh *.rpm
    ;;
  *)
    echo "Unable to determine OS..."
    exit 1
    ;;
esac

