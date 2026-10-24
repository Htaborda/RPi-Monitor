#!/usr/bin/env bats

load "../helpers/test_helper.bash"

setup() {
    start_mock_server 8080 "2.14" 0
    export GITHUB_API_BASE="http://127.0.0.1:8080"
    export TARGET_DIR="/tmp/test_update"
    rm -rf "${TARGET_DIR}"
    mkdir -p "${TARGET_DIR}"

    # First perform a fresh install
    "${INSTALL_SH}" -y --no-service >/dev/null 2>&1
}

teardown() {
    rm -rf "${TARGET_DIR}"
    stop_mock_server 8080
}

@test "Update: detects existing installation and skips when up-to-date" {
    run "${INSTALL_SH}" -y --no-service
    [ "$status" -eq 0 ]
    [[ "$output" =~ "UPDATE (existing installation detected)" ]]
    [[ "$output" =~ "already up to date" ]]
    [[ "$output" =~ "Use --force to reinstall or overwrite" ]]
}

@test "Update: --force forces reinstallation when already up-to-date" {
    run "${INSTALL_SH}" -y --no-service --force
    [ "$status" -eq 0 ]
    [[ "$output" =~ "UPDATE (existing installation detected)" ]]
    [[ "$output" =~ "--force was specified. Proceeding" ]]
    [[ "$output" =~ "Configuring RPi-Monitor" ]]
}
