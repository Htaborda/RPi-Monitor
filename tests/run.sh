#!/usr/bin/env bash
#
# Unified test runner for install.sh using Docker and Bats.
# Can run locally or inside CI runners.
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE_IMAGE="${BASE_IMAGE:-debian:12-slim}"
IMAGE_TAG="rpimonitor-test:${BASE_IMAGE//:/-}"

echo "=========================================================="
echo " Running RPi-Monitor install.sh tests with Docker"
echo " Base Image: ${BASE_IMAGE}"
echo "=========================================================="

# Build test runner Docker image
echo "==> Building test container image (${IMAGE_TAG})..."
docker build \
    --build-arg BASE_IMAGE="${BASE_IMAGE}" \
    -t "${IMAGE_TAG}" \
    -f "${REPO_ROOT}/tests/Dockerfile.test" \
    "${REPO_ROOT}"

# Run bats inside container
echo "==> Executing Bats test suite in container..."
docker run --rm -i \
    -v "${REPO_ROOT}:/workspace" \
    -w /workspace \
    "${IMAGE_TAG}" \
    bats tests/suite/
