#!/usr/bin/env bats

load "../helpers/test_helper.bash"

setup() {
    export TARGET_DIR="/tmp/test_security"
    rm -rf "${TARGET_DIR}"
    mkdir -p "${TARGET_DIR}"
}

teardown() {
    rm -rf "${TARGET_DIR}"
    stop_mock_server 8081
}

@test "Security: rejects package when SHA256 checksum mismatch occurs" {
    start_mock_server 8081 "2.14" 1
    export GITHUB_API_BASE="http://127.0.0.1:8081"

    run "${INSTALL_SH}" -y --no-service
    [ "$status" -eq 1 ]
    [[ "$output" =~ "SHA256 checksum mismatch" ]]
}
