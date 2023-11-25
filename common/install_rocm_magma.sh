#!/bin/bash

# TODO upstream differences from this file is into the (eventual) one in pytorch
# - (1) check for static lib mkl
# - (2) MKLROOT as env var

set -ex

# TODO (2)
MKLROOT=${MKLROOT:-/opt/intel}

ver() {
  printf "%3d%03d%03d%03d" $(echo "$1" | tr '.' ' ');
}

# "install" hipMAGMA into /opt/rocm/magma by copying after build
if [[ $PYTORCH_BRANCH == "release/1.10.1" ]]; then
  if [[ $(ver $ROCM_VERSION) -ge $(ver 6.0) ]]; then
    git clone https://bitbucket.org/mpruthvi1/magma.git -b pyt1_10_rocm6.x
    pushd magma
  else
    git clone https://bitbucket.org/icl/magma.git
    pushd magma
    git checkout magma_ctrl_launch_bounds
  fi
else
  # Version 2.7.2 + ROCm related updates
  # Moved to temp fork SWDEV-429841
  git clone https://bitbucket.org/mpruthvi1/magma.git -b rocm60_gcn_depr
  pushd magma
  git checkout 825f861ae834407946fb748834e4e025ac7d7064
fi

cp make.inc-examples/make.inc.hip-gcc-mkl make.inc
echo 'LIBDIR += -L$(MKLROOT)/lib' >> make.inc
# TODO (1)
if [[ -f "${MKLROOT}/lib/libmkl_core.a" ]]; then
    echo 'LIB = -Wl,--start-group -lmkl_gf_lp64 -lmkl_gnu_thread -lmkl_core -Wl,--end-group -lpthread -lstdc++ -lm -lgomp -lhipblas -lhipsparse' >> make.inc
fi
echo 'LIB += -Wl,--enable-new-dtags -Wl,--rpath,/opt/rocm/lib -Wl,--rpath,$(MKLROOT)/lib -Wl,--rpath,/opt/rocm/magma/lib -ldl' >> make.inc
echo 'DEVCCFLAGS += --gpu-max-threads-per-block=256' >> make.inc
export PATH="${PATH}:/opt/rocm/bin"
if [[ -n "$PYTORCH_ROCM_ARCH" ]]; then
  amdgpu_targets=`echo $PYTORCH_ROCM_ARCH | sed 's/;/ /g'`
else
  amdgpu_targets=`rocm_agent_enumerator | grep -v gfx000 | sort -u | xargs`
fi
for arch in $amdgpu_targets; do
  echo "DEVCCFLAGS += --offload-arch=$arch" >> make.inc
done
# hipcc with openmp flag may cause isnan() on __device__ not to be found; depending on context, compiler may attempt to match with host definition
sed -i 's/^FOPENMP/#FOPENMP/g' make.inc
make -f make.gen.hipMAGMA -j $(nproc)
LANG=C.UTF-8 make lib/libmagma.so -j $(nproc) MKLROOT="${MKLROOT}"
make testing/testing_dgemm -j $(nproc) MKLROOT="${MKLROOT}"
popd
mkdir -p /opt/rocm/magma
mv magma/include /opt/rocm/magma
mv magma/lib /opt/rocm/magma
rm -rf magma

