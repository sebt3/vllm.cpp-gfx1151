#!/usr/bin/env bash
set -euo pipefail

# Fork-local build script for the gfx1151 (Strix Halo) ROCm lane.
#
# Deliberately NOT scripts/build-linux-accelerator-release.sh: that script
# only accepts backend=cuda|vulkan (hardcodes -DVLLM_CPP_HIP=OFF) and drives
# the shared, gated release-archive pipeline (package-server.py, provenance
# metadata, validate-release-archive.py) upstream's container-matrix owns.
# This lane is fork-only infra, so it stays out of that shared surface and
# does the minimum: configure, build, `cmake --install` the vllm-server
# component. No archive, no provenance, no checksum sidecar.
#
# Usage: build-rocm-gfx1151-release.sh BUILD_DIR INSTALL_PREFIX

if [[ $# -ne 2 ]]; then
  echo "usage: $0 BUILD_DIR INSTALL_PREFIX" >&2
  exit 2
fi

build_dir=$1
prefix=$2
: "${ROCM_PATH:=/opt/rocm}"

cmake -S . -B "$build_dir" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
  -DVLLM_CPP_BUILD_TESTS=ON \
  -DVLLM_CPP_BUILD_EXAMPLES=OFF \
  -DVLLM_CPP_SERVER=ON \
  -DVLLM_CPP_CUDA=OFF \
  -DVLLM_CPP_CUTLASS_FETCH=OFF \
  -DVLLM_CPP_HIP=ON \
  -DVLLM_CPP_HIP_ARCHITECTURES=gfx1151 \
  -DROCM_PATH="$ROCM_PATH" \
  -DVLLM_CPP_LITERAL_STATIC=OFF \
  -DVLLM_CPP_METAL=OFF \
  -DVLLM_CPP_MLX=OFF \
  -DMLX_ROOT= \
  -DVLLM_CPP_TRITON=OFF \
  -DVLLM_CPP_VULKAN=OFF

# server: the shipped binary. test_rocm_backend / test_backend_cross_device:
# compiled to prove the cherry-picked ROCm kernels link against this exact
# TheRock SDK. Not run here -- a hosted CI runner has no gfx1151 device; ctest
# execution is real-hardware-only (AGENTS.md "a gate you cannot run stays
# PENDING"), see docs/ROCM.md Sec.5.2.
cmake --build "$build_dir" --target server test_rocm_backend test_backend_cross_device -j "${JOBS:-2}"

mkdir -p "$prefix"
cmake --install "$build_dir" --prefix "$prefix" --component vllm-server
