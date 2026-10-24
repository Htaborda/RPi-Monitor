#!/usr/bin/env bats

load "../helpers/test_helper.bash"

setup() {
    start_mock_server 8080 "2.14" 0
    export GITHUB_API_BASE="http://127.0.0.1:8080"
    export TARGET_DIR="/tmp/test_config_preserv"
    rm -rf "${TARGET_DIR}"
    mkdir -p "${TARGET_DIR}"

    # Install initial version
    "${INSTALL_SH}" -y --no-service >/dev/null 2>&1
}

teardown() {
    rm -rf "${TARGET_DIR}"
    stop_mock_server 8080
}

@test "Config: preserves existing modified configuration and creates .new templates" {
    local daemon_conf="${TARGET_DIR}/etc/rpimonitor/daemon.conf"
    local template_conf="${TARGET_DIR}/etc/rpimonitor/template/version.conf"

    # Modify existing configs
    echo "# Custom User Config" >> "${daemon_conf}"
    echo "# Custom User Template" >> "${template_conf}"

    # Run installation with --force
    run "${INSTALL_SH}" -y --no-service --force
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Existing configuration in ${TARGET_DIR}/etc/rpimonitor/ is preserved." ]]
    [[ "$output" =~ "Template version.conf differs from the packaged version, saved as version.conf.new" ]]

    # Verify custom user modifications remain in original file
    grep -q "Custom User Config" "${daemon_conf}"
    grep -q "Custom User Template" "${template_conf}"

    # Verify .new file was created for the differing template
    [ -f "${template_conf}.new" ]
}
