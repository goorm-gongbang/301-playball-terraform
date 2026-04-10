#!/bin/bash
# Redis Lambda Layer 빌드
# 사용법: ./build.sh

set -e

LAYER_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="${LAYER_DIR}/python"

rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

pip install redis -t "${BUILD_DIR}" --quiet --platform manylinux2014_aarch64 --only-binary=:all:

cd "${LAYER_DIR}"
rm -f redis-layer.zip
zip -r redis-layer.zip python/ -q

rm -rf "${BUILD_DIR}"

echo "Built: ${LAYER_DIR}/redis-layer.zip"
