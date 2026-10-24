#!/usr/bin/env bash
#
# Unified test runner for install.sh using Docker and Bats.
# Can run locally or inside CI runners.
#
# Options:
#   --coverage   Run test suite with kcov to generate code coverage metrics
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE_IMAGE="${BASE_IMAGE:-debian:12-slim}"
IMAGE_TAG="rpimonitor-test:${BASE_IMAGE//:/-}"
COVERAGE="${COVERAGE:-0}"

# Parse command line options
for arg in "$@"; do
    case "${arg}" in
        --coverage)
            COVERAGE=1
            ;;
        -h|--help)
            echo "Usage: $0 [--coverage]"
            echo "  --coverage   Collect detailed test coverage on install.sh using kcov"
            exit 0
            ;;
        *)
            echo "Unknown option: ${arg}" >&2
            echo "Usage: $0 [--coverage]" >&2
            exit 1
            ;;
    esac
done

echo "=========================================================="
echo " Running RPi-Monitor install.sh tests with Docker"
echo " Base Image: ${BASE_IMAGE}"
if [[ "${COVERAGE}" -eq 1 ]]; then
    echo " Coverage:   ENABLED"
fi
echo "=========================================================="

# Build test runner Docker image
echo "==> Building test container image (${IMAGE_TAG})..."
docker build \
    --build-arg BASE_IMAGE="${BASE_IMAGE}" \
    -t "${IMAGE_TAG}" \
    -f "${REPO_ROOT}/tests/Dockerfile.test" \
    "${REPO_ROOT}"

if [[ "${COVERAGE}" -eq 1 ]]; then
    COVERAGE_DIR="${REPO_ROOT}/coverage"
    rm -rf "${COVERAGE_DIR}"
    mkdir -p "${COVERAGE_DIR}"

    echo "==> Executing Bats test suite with kcov coverage in container..."
    # kcov requires ptrace permissions inside container
    docker run --rm -i \
        --privileged \
        -v "${REPO_ROOT}:/workspace" \
        -w /workspace \
        "${IMAGE_TAG}" \
        kcov --include-pattern=/workspace/install.sh /workspace/coverage bats tests/suite/

    # Ensure permissions on generated coverage files belong to current user
    if [[ -d "${COVERAGE_DIR}" ]]; then
        # Check if coverage.json was generated and display summary
        SUMMARY_JSON=$(find "${COVERAGE_DIR}" -name "coverage.json" 2>/dev/null | head -n 1)
        if [[ -n "${SUMMARY_JSON}" && -f "${SUMMARY_JSON}" ]]; then
            PERCENT=$(jq -r '.files[] | select(.file=="/workspace/install.sh") | .percent_covered' "${SUMMARY_JSON}" 2>/dev/null || echo "")
            COVERED=$(jq -r '.files[] | select(.file=="/workspace/install.sh") | .covered_lines' "${SUMMARY_JSON}" 2>/dev/null || echo "")
            TOTAL=$(jq -r '.files[] | select(.file=="/workspace/install.sh") | .total_lines' "${SUMMARY_JSON}" 2>/dev/null || echo "")

            echo ""
            echo "=========================================================="
            echo " Code Coverage Summary for install.sh"
            echo "=========================================================="
            if [[ -n "${PERCENT}" ]]; then
                echo " Coverage: ${PERCENT}% (${COVERED}/${TOTAL} lines)"
            fi
            echo " Detailed HTML report: file://${COVERAGE_DIR}/index.html"
            echo "=========================================================="
        fi
    fi
else
    # Run bats inside container
    echo "==> Executing Bats test suite in container..."
    docker run --rm -i \
        -v "${REPO_ROOT}:/workspace" \
        -w /workspace \
        "${IMAGE_TAG}" \
        bats tests/suite/
fi
