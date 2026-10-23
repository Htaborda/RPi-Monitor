#!/usr/bin/env bash
#
# Build script for RPi-Monitor root-based ZIP distribution archive.
# Compatible with Linux distributions (Debian, Arch, Fedora, etc.) and CI environments.
#

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# 1. Determine version from argument or git tag
VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
    if git -C "${REPO_ROOT}" describe --tags --exact-match >/dev/null 2>&1; then
        VERSION=$(git -C "${REPO_ROOT}" describe --tags --exact-match)
    elif git -C "${REPO_ROOT}" describe --tags >/dev/null 2>&1; then
        VERSION=$(git -C "${REPO_ROOT}" describe --tags)
    else
        VERSION=$(cat "${REPO_ROOT}/VERSION" 2>/dev/null || echo "dev")
    fi
fi
# Strip leading 'v' if present (e.g. v2.14 -> 2.14)
VERSION="${VERSION#v}"

echo "==> Building RPi-Monitor ZIP package for version: ${VERSION}"

# 2. Prepare staging directories
BUILD_DIR="${REPO_ROOT}/build"
STAGING_DIR="${BUILD_DIR}/staging"

rm -rf "${STAGING_DIR}"
mkdir -p "${STAGING_DIR}" "${BUILD_DIR}"

# 3. Copy files from src/ to staging/
cp -a "${REPO_ROOT}/src/"* "${STAGING_DIR}/"

# Clean any obsolete debian-specific repositories list
rm -rf "${STAGING_DIR}/etc/apt"

# 4. Substitute {DEVELOPMENT} placeholder with actual version
sed -i "s/{DEVELOPMENT}/${VERSION}/g" "${STAGING_DIR}/usr/bin/rpimonitord"
sed -i "s/{DEVELOPMENT}/${VERSION}/g" "${STAGING_DIR}/usr/share/rpimonitor/web/js/rpimonitor.js"

# 5. Ensure execution rights and permissions
chmod +x "${STAGING_DIR}/usr/bin/rpimonitord"
chmod +x "${STAGING_DIR}/usr/share/rpimonitor/scripts/"*.pl
chmod +x "${STAGING_DIR}/usr/share/rpimonitor/scripts/"*.sh
chmod 644 "${STAGING_DIR}/etc/cron.d/rpimonitor"

# Ensure symlink for rpimonitord-snmp
(cd "${STAGING_DIR}/usr/bin" && ln -sf rpimonitord rpimonitord-snmp)

# 6. Create ZIP archive
ZIP_NAME="rpimonitor-${VERSION}.zip"
GENERIC_ZIP_NAME="rpimonitor.zip"
TARGET_ZIP="${BUILD_DIR}/${ZIP_NAME}"
GENERIC_ZIP="${BUILD_DIR}/${GENERIC_ZIP_NAME}"

rm -f "${TARGET_ZIP}" "${GENERIC_ZIP}"

# -y stores the symlinks (data.conf, rpimonitord-snmp) as links
(cd "${STAGING_DIR}" && zip -q -r -y "${TARGET_ZIP}" *)

# Create generic copy
cp -f "${TARGET_ZIP}" "${GENERIC_ZIP}"

# Generate SHA256 checksums
(
    cd "${BUILD_DIR}"
    sha256sum "${ZIP_NAME}" > "${ZIP_NAME}.sha256"
    sha256sum "${GENERIC_ZIP_NAME}" > "${GENERIC_ZIP_NAME}.sha256"
)

# 7. Clean up staging directory
rm -rf "${STAGING_DIR}"

echo "==> Package created successfully:"
echo "    Archive: ${TARGET_ZIP}"
echo "    Generic: ${GENERIC_ZIP}"
echo "    SHA256:  $(cat "${TARGET_ZIP}.sha256")"
