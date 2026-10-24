#!/usr/bin/env bats

load "../helpers/test_helper.bash"

setup() {
    export GITHUB_API_BASE="http://127.0.0.1:8080"
}

@test "CLI: -h or --help displays usage and returns 0" {
    run "${INSTALL_SH}" -h
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Usage:" ]]
    [[ "$output" =~ "--dry-run" ]]
    [[ "$output" =~ "--version" ]]

    run "${INSTALL_SH}" --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Usage:" ]]
}

@test "CLI: Unknown option produces error and returns 1" {
    run "${INSTALL_SH}" --invalid-option
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Unknown option" ]]
}

@test "CLI: --version without argument produces error and returns 1" {
    run "${INSTALL_SH}" --version
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Option '--version' requires a version argument" ]]
}

@test "CLI: Non-interactive execution without -y produces error and returns 1" {
    # Run with stdin closed / /dev/null
    run "${INSTALL_SH}" < /dev/null
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Non-interactive environment detected without -y/--yes" ]]
}

@test "CLI: Unexpected positional argument returns error and status 1" {
    run "${INSTALL_SH}" archive.zip
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Usage:" ]]
}

@test "CLI: Missing required tools triggers installation advice and exit 1" {
    local fake_bin_dir="/tmp/fake_bin_tools_$$"
    mkdir -p "${fake_bin_dir}"

    # Symlink system binaries into fake_bin_dir but omit unzip
    for bin in /bin/* /usr/bin/*; do
        bname=$(basename "$bin")
        if [ "$bname" != "unzip" ] && [ -x "$bin" ]; then
            ln -s "$bin" "${fake_bin_dir}/${bname}" 2>/dev/null || true
        fi
    done

    PATH="${fake_bin_dir}" run "${INSTALL_SH}" -y --dry-run
    rm -rf "${fake_bin_dir}"

    [ "$status" -eq 1 ]
    [[ "$output" =~ "unzip" ]]
    [[ "$output" =~ "is not installed" ]]
    [[ "$output" =~ "sudo apt update && sudo apt install -y" ]]
}
