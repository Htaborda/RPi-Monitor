#!/usr/bin/env bash
#
# RPi-Monitor Unified Installation and Update Script
# Target: Debian / Raspbian / Ubuntu
# Distribution format: Root-based ZIP archive
#

set -euo pipefail

# Color support detection (terminal check and NO_COLOR standard)
if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]] && [[ "${TERM:-}" != "dumb" ]]; then
    C_RESET='\033[0m'
    C_BOLD='\033[1m'
    C_DIM='\033[2m'
    C_RED='\033[0;31m'
    C_GREEN='\033[0;32m'
    C_YELLOW='\033[0;33m'
    C_BLUE='\033[0;34m'
    C_MAGENTA='\033[0;35m'
    C_CYAN='\033[0;36m'
    C_BOLD_RED='\033[1;31m'
    C_BOLD_GREEN='\033[1;32m'
    C_BOLD_YELLOW='\033[1;33m'
    C_BOLD_BLUE='\033[1;34m'
    C_BOLD_CYAN='\033[1;36m'
else
    C_RESET=''
    C_BOLD=''
    C_DIM=''
    C_RED=''
    C_GREEN=''
    C_YELLOW=''
    C_BLUE=''
    C_MAGENTA=''
    C_CYAN=''
    C_BOLD_RED=''
    C_BOLD_GREEN=''
    C_BOLD_YELLOW=''
    C_BOLD_BLUE=''
    C_BOLD_CYAN=''
fi

log_info() {
    echo -e "${C_BOLD_BLUE}[INFO]${C_RESET} $*"
}

log_step() {
    echo -e "\n${C_BOLD_CYAN}==>${C_RESET} ${C_BOLD}$*${C_RESET}"
}

log_success() {
    echo -e "${C_BOLD_GREEN}[OK]${C_RESET} $*"
}

log_warn() {
    echo -e "${C_BOLD_YELLOW}[WARN]${C_RESET} $*"
}

log_error() {
    echo -e "${C_BOLD_RED}[ERROR]${C_RESET} $*" >&2
}

check_and_install_tools() {
    local packages=("curl" "jq" "unzip")
    local missing_packages=()

    # Vérification de chaque outil
    for pkg in "${packages[@]}"; do
        if ! command -v "$pkg" &> /dev/null; then
            log_error "${C_BOLD}$pkg${C_RESET} is not installed."
            missing_packages+=("$pkg")
        fi
    done

    # Si des paquets manquent, on affiche la commande d'installation
    if [ ${#missing_packages[@]} -gt 0 ]; then
        echo "Execute the following command to install missing package(s):"
        echo "  sudo apt update && sudo apt install -y ${missing_packages[*]}"
        exit 1
    fi
}

check_and_install_tools || exit 1

# This script dependencies are installed

GITHUB_API_BASE="${GITHUB_API_BASE:-https://api.github.com/repos/RPi-Monitor/RPi-Monitor}"
DRY_RUN=""
OPT_YES=0
OPT_FORCE=0
OPT_NO_SERVICE=0
ZIP_FILE=""
ZIP_PROVIDED=0
PRE_RELEASE="false"
PACKAGE_VERSION=""
TARGET_DIR="${TARGET_DIR:-}"


show_help() {
    cat << 'EOF'
Usage: sudo ./RPi-Monitor-install_or_update.sh [OPTIONS] [ARCHIVE.zip]

Unified installation and update script for RPi-Monitor (Debian / Raspbian / Ubuntu).

Arguments:
  ARCHIVE.zip        Path to RPi-Monitor zip package (default: ./rpimonitor.zip)

Options:
  -y, --yes          Non-interactive / automatic mode (required to update without a TTY)
  --force            Force installation/update even if already up to date
  --dry-run          Simulate actions: prefix system commands with 'echo' without modifying system
  --pre-release      Install the newest release, pre-releases included (may not be stable)
  --no-service       Do not enable or start systemd service (for containerized CI environments)
  -h, --help         Show this help message and exit
EOF
}

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN="echo"
            shift
            ;;
        --pre-release)
            PRE_RELEASE="true"
            shift
            ;;
        -y|--yes)
            OPT_YES=1
            shift
            ;;
        --force)
            OPT_FORCE=1
            shift
            ;;
        --no-service)
            OPT_NO_SERVICE=1
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        -*)
            log_error "Unknown option '$1'"
            show_help >&2
            exit 1
            ;;
        *)
            if [[ -z "$ZIP_FILE" ]]; then
                ZIP_FILE="$1"
                ZIP_PROVIDED=1
            else
                log_error "Unexpected argument '$1'"
                show_help >&2
                exit 1
            fi
            shift
            ;;
    esac
done

# Verify root privileges (strictly required in both normal and dry-run modes)
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root (e.g. using sudo)."
    exit 1
fi

# Refuse to overwrite the Debian package: a later 'apt remove' or 'apt upgrade'
# would delete or replace the files deployed here. Its removal keeps
# /etc/rpimonitor, which this script then preserves.
if [[ "$(dpkg-query -W -f='${Status}' rpimonitor 2>/dev/null)" == "install ok installed" ]]; then
    log_error "RPi-Monitor is installed from its Debian package."
    log_error "Remove it first (configuration in /etc/rpimonitor is kept), then rerun this script:"
    log_error "  sudo apt remove rpimonitor"
    exit 1
fi

# ---------------------------------------------------------------------------
# GitHub Releases: select and download the appropriate distribution ZIP
# ---------------------------------------------------------------------------

# Fetch the latest stable release JSON from GitHub (/releases/latest).
# This endpoint natively excludes pre-releases and drafts.
# Prints the release JSON on stdout; returns 1 on error.
_rpi_fetch_stable_release() {
    local response
    response=$(curl --fail --location --silent --show-error \
        "${GITHUB_API_BASE}/releases/latest" 2>&1) || {
        log_error "Failed to fetch latest stable release from GitHub API: ${response}"
        return 1
    }
    local tag
    tag=$(echo "${response}" | jq -r '.tag_name // empty' 2>/dev/null)
    if [[ -z "${tag}" ]]; then
        log_error "GitHub API response is missing the 'tag_name' field."
        log_error "Response: ${response}"
        return 1
    fi
    echo "${response}"
}

# Fetch the newest release JSON from GitHub, pre-release or stable.
# Drafts are excluded; the newest is picked by published_at among the 100
# most recent releases, so an older pre-release never wins over a stable one.
# Prints the release JSON on stdout; returns 1 if none found or on error.
_rpi_fetch_newest_release() {
    local response
    response=$(curl --fail --location --silent --show-error \
        "${GITHUB_API_BASE}/releases?per_page=100" 2>&1) || {
        log_error "Failed to fetch releases list from GitHub API: ${response}"
        return 1
    }

    local release
    release=$(echo "${response}" | jq -c \
        '[.[] | select(.draft == false)] | max_by(.published_at) // empty' 2>/dev/null)
    if [[ -z "${release}" ]]; then
        log_error "No release found on GitHub (excluding drafts)."
        log_error "Response: ${response}"
        return 1
    fi

    echo "${release}"
}

# Select the appropriate release and download its distribution ZIP asset.
# Sets globals ZIP_FILE and PACKAGE_VERSION on success.
# Args: $1 = "true" for pre-release mode, "false" (default) for stable mode.
_rpi_download_release_zip() {
    local pre_release="${1:-false}"

    local release_json
    if [[ "${pre_release}" == "true" ]]; then
        log_info "Fetching newest release (pre-releases included) from GitHub..."
        release_json=$(_rpi_fetch_newest_release) || return 1
    else
        log_info "Fetching latest stable release from GitHub..."
        release_json=$(_rpi_fetch_stable_release) || return 1
    fi

    local tag_name
    tag_name=$(echo "${release_json}" | jq -r '.tag_name')
    # Strip leading 'v' (e.g. v2.14-rc1 -> 2.14-rc1)
    local version="${tag_name#v}"
    local asset_name="rpimonitor-${version}.zip"
    local sha256_asset_name="${asset_name}.sha256"

    log_info "Selected release: ${tag_name}  (asset: ${asset_name})"

    # Locate the versioned distribution ZIP in the release assets.
    # browser_download_url points to an explicitly uploaded asset, not a
    # GitHub auto-generated source archive.
    local download_url
    download_url=$(echo "${release_json}" | jq -r \
        --arg name "${asset_name}" \
        '.assets[] | select(.name == $name) | .browser_download_url // empty')

    if [[ -z "${download_url}" ]]; then
        log_error "Asset '${asset_name}' not found in release '${tag_name}'."
        log_error "Available assets: $(echo "${release_json}" | jq -r '[.assets[].name] | join(", ")')"
        return 1
    fi

    # Download into the temporary directory, removed on exit
    local tmp_zip="${TMP_DIR}/${asset_name}"
    log_info "Downloading ${asset_name}..."
    if ! curl --fail --location --silent --show-error \
            "${download_url}" --output "${tmp_zip}"; then
        log_error "Failed to download '${asset_name}' from '${download_url}'."
        return 1
    fi

    # Reject empty downloads
    if [[ ! -s "${tmp_zip}" ]]; then
        log_error "Downloaded file is empty: ${asset_name}"
        return 1
    fi

    # Validate ZIP magic bytes (PK\x03\x04 = 504b0304)
    local magic
    magic=$(od -An -tx1 -N4 "${tmp_zip}" | tr -d ' \n')
    if [[ "${magic}" != "504b0304"* ]]; then
        log_error "Downloaded file is not a valid ZIP archive: ${asset_name}"
        return 1
    fi

    # SHA256 integrity check: the release workflow always publishes the
    # .sha256 asset, so a missing or unreadable one is an error
    local sha256_url
    sha256_url=$(echo "${release_json}" | jq -r \
        --arg name "${sha256_asset_name}" \
        '.assets[] | select(.name == $name) | .browser_download_url // empty')

    if [[ -z "${sha256_url}" ]]; then
        log_error "Asset '${sha256_asset_name}' not found in release '${tag_name}'."
        return 1
    fi

    log_info "Verifying SHA256 checksum..."
    local tmp_sha256="${TMP_DIR}/${sha256_asset_name}"
    if ! curl --fail --location --silent --show-error \
            "${sha256_url}" --output "${tmp_sha256}"; then
        log_error "Failed to download '${sha256_asset_name}' from '${sha256_url}'."
        return 1
    fi
    local expected_hash actual_hash
    expected_hash=$(awk '{print $1}' "${tmp_sha256}")
    actual_hash=$(sha256sum "${tmp_zip}" | awk '{print $1}')
    if [[ "${expected_hash}" != "${actual_hash}" ]]; then
        log_error "SHA256 checksum mismatch for '${asset_name}'."
        log_error "  Expected: ${expected_hash}"
        log_error "  Actual:   ${actual_hash}"
        return 1
    fi
    log_success "SHA256 checksum verified."

    PACKAGE_VERSION="${version}"
    ZIP_FILE="${tmp_zip}"
    log_success "Downloaded: ${tmp_zip}"
}

# Temporary directory for the downloaded archive and its extraction,
# removed on exit whatever the outcome
TMP_DIR=$(mktemp -d)
cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

# If no ZIP archive was supplied on the command line, download the appropriate
# release from GitHub. Otherwise use the caller-supplied file as-is.
if [[ ${ZIP_PROVIDED} -eq 0 ]]; then
    _rpi_download_release_zip "${PRE_RELEASE}" || exit 1
fi

# Verify the package archive is present (guards the case where a path was
# provided explicitly but does not exist)
if [[ ! -f "$ZIP_FILE" ]]; then
    log_error "Package archive '$ZIP_FILE' not found."
    exit 1
fi

# Detect existing installation from the binary: the configuration alone may
# be a leftover of 'apt remove' and does not mean the program is installed.
CONF_DIR="${TARGET_DIR}/etc/rpimonitor"
BIN_FILE="${TARGET_DIR}/usr/bin/rpimonitord"
IS_EXISTING=0

if [[ -f "$BIN_FILE" ]]; then
    IS_EXISTING=1
fi

# Read the version from the script rather than running 'rpimonitord -V', which
# loads the configuration and rewrites stat/empty.rrd before parsing options.
get_installed_version() {
    [[ $IS_EXISTING -eq 1 ]] || return 0
    sed -n 's/^my \$VERSION *= *"\(.*\)";$/\1/p' "$BIN_FILE"
}

INSTALLED_VERSION=$(get_installed_version)
# PACKAGE_VERSION is set by _rpi_download_release_zip when downloading from
# GitHub. When a ZIP is provided explicitly it remains empty (version unknown).

# Display Welcome Banner
echo ""
echo -e "${C_BOLD_CYAN}┌───────────────────────────────────────────────────────────┐${C_RESET}"
echo -e "${C_BOLD_CYAN}│${C_RESET}              ${C_BOLD}RPi-Monitor Installer & Updater${C_RESET}              ${C_BOLD_CYAN}│${C_RESET}"
echo -e "${C_BOLD_CYAN}└───────────────────────────────────────────────────────────┘${C_RESET}"
echo ""

if [[ $IS_EXISTING -eq 1 ]]; then
    ACTION_DESC="update"
    echo -e "  ${C_BOLD}Operation Mode:${C_RESET}   ${C_BOLD_YELLOW}UPDATE${C_RESET} (existing installation detected)"
    echo -e "  ${C_BOLD}Installed Ver:${C_RESET}    ${INSTALLED_VERSION:-unknown}"
    echo -e "  ${C_BOLD}Target Ver:${C_RESET}       ${PACKAGE_VERSION:-unknown}"
else
    ACTION_DESC="installation"
    echo -e "  ${C_BOLD}Operation Mode:${C_RESET}   ${C_BOLD_GREEN}FRESH INSTALLATION${C_RESET} (new installation)"
    echo -e "  ${C_BOLD}Target Ver:${C_RESET}       ${PACKAGE_VERSION:-unknown}"
    echo -e "  ${C_DIM}Note: Dependencies will be installed.${C_RESET}"
fi
if [[ -d "$CONF_DIR" ]]; then
    echo -e "  ${C_DIM}Note: Existing configuration in ${CONF_DIR} will be preserved.${C_RESET}"
else
    echo -e "  ${C_DIM}Note: Default configuration will be deployed.${C_RESET}"
fi

echo -e "  ${C_BOLD}Package Archive:${C_RESET}  ${ZIP_FILE}"
if [[ -n "$TARGET_DIR" ]]; then
    echo -e "  ${C_BOLD}Target Root:${C_RESET}      ${TARGET_DIR}"
fi
if [[ $OPT_NO_SERVICE -eq 1 ]]; then
    echo -e "  ${C_BOLD}Service:${C_RESET}          ${C_YELLOW}Disabled (--no-service)${C_RESET}"
fi
if [[ -n "$DRY_RUN" ]]; then
    echo -e "  ${C_BOLD}Dry Run:${C_RESET}          ${C_BOLD_YELLOW}Active (simulation mode)${C_RESET}"
fi
echo ""

# Check if already up to date
if [[ $IS_EXISTING -eq 1 && -n "$INSTALLED_VERSION" && -n "$PACKAGE_VERSION" && "$INSTALLED_VERSION" == "$PACKAGE_VERSION" ]]; then
    if [[ $OPT_FORCE -eq 0 ]]; then
        log_success "RPi-Monitor is already up to date (version ${INSTALLED_VERSION}). Nothing to do."
        log_info "Use --force to reinstall or overwrite."
        exit 0
    else
        log_warn "RPi-Monitor is already at version ${INSTALLED_VERSION}, but --force was specified. Proceeding."
    fi
fi

# Confirmation prompt
if [[ $OPT_YES -eq 1 ]]; then
    log_info "Non-interactive mode (-y): proceeding with ${ACTION_DESC} automatically."
elif [[ -t 0 ]]; then
    read -r -p "Do you want to proceed with the ${ACTION_DESC}? [y/N] " response
    case "$response" in
        [yY]|[yY][eE][sS])
            log_info "Proceeding with ${ACTION_DESC}..."
            ;;
        *)
            log_warn "Operation cancelled by user. Exiting."
            exit 0
            ;;
    esac
else
    log_error "Non-interactive environment detected without -y/--yes."
    log_error "Please specify -y/--yes to confirm automatically, or run in an interactive terminal."
    exit 1
fi

# Extract ZIP archive into the temporary directory
log_step "Extracting package archive..."
log_info "Extracting $ZIP_FILE to temporary directory..."
unzip -q "$ZIP_FILE" -d "$TMP_DIR"

# Install prerequisite packages via apt-get (fresh installation only)
if [[ $IS_EXISTING -eq 0 ]]; then
    log_step "Installing prerequisite packages..."
    export DEBIAN_FRONTEND=noninteractive
    ${DRY_RUN} apt-get update -y
    ${DRY_RUN} apt-get install -y --no-install-recommends \
        perl \
        librrds-perl \
        libhttp-daemon-perl \
        libjson-perl \
        libipc-sharelite-perl \
        libfile-which-perl \
        libsnmp-extension-passpersist-perl \
        aptitude
else
    log_info "Update mode: skipping prerequisite package installation."
fi

# Create target directories (also on update: any of them may be missing)
log_step "Creating target directories..."
${DRY_RUN} mkdir -p "${TARGET_DIR}/usr/bin"
${DRY_RUN} mkdir -p "${TARGET_DIR}/usr/share/rpimonitor"
${DRY_RUN} mkdir -p "${TARGET_DIR}/var/lib/rpimonitor"
${DRY_RUN} mkdir -p "${TARGET_DIR}/etc/cron.d"
${DRY_RUN} mkdir -p "${TARGET_DIR}/usr/lib/systemd/system"

# Deploy application files
log_step "Deploying RPi-Monitor files..."

# Binaries
if [[ -f "$TMP_DIR/usr/bin/rpimonitord" ]]; then
    ${DRY_RUN} cp "$TMP_DIR/usr/bin/rpimonitord" "${TARGET_DIR}/usr/bin/rpimonitord"
    ${DRY_RUN} chmod +x "${TARGET_DIR}/usr/bin/rpimonitord"
    ${DRY_RUN} ln -sf rpimonitord "${TARGET_DIR}/usr/bin/rpimonitord-snmp"
fi

# Web assets and scripts
if [[ -d "$TMP_DIR/usr/share/rpimonitor" ]]; then
    ${DRY_RUN} cp -r "$TMP_DIR/usr/share/rpimonitor/"* "${TARGET_DIR}/usr/share/rpimonitor/"
    ${DRY_RUN} chmod +x "${TARGET_DIR}/usr/share/rpimonitor/scripts/"*.pl 2>/dev/null || true
fi

# Cron configuration
if [[ -f "$TMP_DIR/etc/cron.d/rpimonitor" ]]; then
    ${DRY_RUN} cp "$TMP_DIR/etc/cron.d/rpimonitor" "${TARGET_DIR}/etc/cron.d/rpimonitor"
fi

# SNMP configuration if present in package
if [[ -d "$TMP_DIR/etc/snmp" ]]; then
    ${DRY_RUN} mkdir -p "${TARGET_DIR}/etc/snmp"
    ${DRY_RUN} cp -r "$TMP_DIR/etc/snmp/"* "${TARGET_DIR}/etc/snmp/"
fi

# Manual pages if present in package
if [[ -d "$TMP_DIR/usr/share/man" ]]; then
    ${DRY_RUN} mkdir -p "${TARGET_DIR}/usr/share/man/man1" "${TARGET_DIR}/usr/share/man/man5"
    ${DRY_RUN} cp -r "$TMP_DIR/usr/share/man/"* "${TARGET_DIR}/usr/share/man/" 2>/dev/null || true
fi

# Deploy systemd unit files
if [[ -d "$TMP_DIR/usr/lib/systemd/system" ]]; then
    ${DRY_RUN} cp "$TMP_DIR/usr/lib/systemd/system/rpimonitord.service" "${TARGET_DIR}/usr/lib/systemd/system/"
    ${DRY_RUN} cp "$TMP_DIR/usr/lib/systemd/system/rpimonitord-upgradable."* "${TARGET_DIR}/usr/lib/systemd/system/" 2>/dev/null || true
fi

# Deploy var/lib/rpimonitor files without overwriting existing data or RRDs
if [[ -d "$TMP_DIR/var/lib/rpimonitor" ]]; then
    for item in "$TMP_DIR/var/lib/rpimonitor/"*; do
        bname=$(basename "$item")
        if [[ ! -e "${TARGET_DIR}/var/lib/rpimonitor/$bname" ]]; then
            ${DRY_RUN} cp -r "$item" "${TARGET_DIR}/var/lib/rpimonitor/"
        fi
    done
fi

# Configuration handling:
# No configuration directory: deploy configuration and templates from zip.
# Existing one (update or leftover): strictly preserve it untouched.
log_step "Configuring RPi-Monitor..."
if [[ ! -d "${CONF_DIR}" ]]; then
    log_info "No configuration found: deploying configuration and templates..."
    ${DRY_RUN} mkdir -p "${CONF_DIR}"
    ${DRY_RUN} cp -r "$TMP_DIR/etc/rpimonitor/"* "${CONF_DIR}/"
    if [[ ! -e "${CONF_DIR}/data.conf" ]]; then
        ${DRY_RUN} ln -sf template/raspbian.conf "${CONF_DIR}/data.conf"
    fi
else
    log_info "Existing configuration and templates in ${CONF_DIR}/ are preserved untouched."
fi

# Systemd service activation and startup.
# The service is not stopped before deploying: rpimonitord runs from its
# compiled copy in memory, so a failed update leaves the old one running.
log_step "Configuring systemd service..."
if [[ $OPT_NO_SERVICE -eq 0 ]]; then
    if [[ -d /run/systemd/system ]]; then
        log_info "Enabling and restarting rpimonitord systemd service..."
        ${DRY_RUN} systemctl daemon-reload
        ${DRY_RUN} systemctl enable rpimonitord
        ${DRY_RUN} systemctl restart rpimonitord
    else
        log_info "systemd is not active in this environment. Skipping service management."
    fi
else
    log_info "Service activation skipped (--no-service)."
fi

# Post-install package status initialization
if [[ -x "${TARGET_DIR}/usr/share/rpimonitor/scripts/updatePackagesStatus.pl" ]]; then
    log_step "Initializing package status..."
    ${DRY_RUN} "${TARGET_DIR}/usr/share/rpimonitor/scripts/updatePackagesStatus.pl" 2>/dev/null || true
fi

echo ""
echo -e "${C_BOLD_GREEN}┌───────────────────────────────────────────────────────────┐${C_RESET}"
echo -e "${C_BOLD_GREEN}│${C_RESET}  ${C_BOLD}RPi-Monitor installation/update completed successfully!${C_RESET}  ${C_BOLD_GREEN}│${C_RESET}"
echo -e "${C_BOLD_GREEN}│${C_RESET}                                                           ${C_BOLD_GREEN}│${C_RESET}"
echo -e "${C_BOLD_GREEN}│${C_RESET}  Access the web interface at: ${C_BOLD_CYAN}http://<server-ip>:8888/${C_RESET}    ${C_BOLD_GREEN}│${C_RESET}"
echo -e "${C_BOLD_GREEN}└───────────────────────────────────────────────────────────┘${C_RESET}"
echo ""
