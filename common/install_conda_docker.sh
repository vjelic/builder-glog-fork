#!/usr/bin/env bash
set -ex

export PATH=/opt/conda/bin:$PATH

conda remove -y mamba conda-libmamba-solver libmamba libmambapy

conda install -y \
       python=3.10 \
       "conda=23.5.2" \
       openssl=1.1.1* \
       conda-build anaconda-client git ninja

/opt/conda/bin/pip install --no-cache-dir cmake==3.18.2
conda remove -y --force patchelf

