#!/usr/bin/env bats

load "../helpers/test_helper.bash"

setup() {
    start_mock_server 8080 "2.14" 0
    export GITHUB_API_BASE="http://127.0.0.1:8080"
    export TARGET_DIR="/tmp/test_fresh_install"
    rm -rf "${TARGET_DIR}"
    mkdir -p "${TARGET_DIR}"
}

teardown() {
    rm -rf "${TARGET_DIR}"
    stop_mock_server 8080
}

@test "Fresh Install: deploys all binaries, configurations, and assets" {
    run "${INSTALL_SH}" -y --no-service
    [ "$status" -eq 0 ]
    [[ "$output" =~ "FRESH INSTALLATION" ]]
    [[ "$output" =~ "SHA256 checksum verified" ]]

    # Verify daemon binary and symlink
    [ -f "${TARGET_DIR}/usr/bin/rpimonitord" ]
    [ -x "${TARGET_DIR}/usr/bin/rpimonitord" ]
    [ -L "${TARGET_DIR}/usr/bin/rpimonitord-snmp" ]

    # Verify configuration
    [ -f "${TARGET_DIR}/etc/rpimonitor/daemon.conf" ]
    [ -d "${TARGET_DIR}/etc/rpimonitor/template" ]
    [ -f "${TARGET_DIR}/etc/rpimonitor/template/version.conf" ]

    # Verify web assets & scripts
    [ -d "${TARGET_DIR}/usr/share/rpimonitor/web" ]
    [ -x "${TARGET_DIR}/usr/share/rpimonitor/scripts/updatePackagesStatus.pl" ]

    # Verify systemd service unit
    [ -f "${TARGET_DIR}/usr/lib/systemd/system/rpimonitord.service" ]
}
