# RPi-Monitor Organization

2026-07-14 is a great day... yes, this is the [French national day](https://en.wikipedia.org/wiki/Bastille_Day) but it’s also a new milestone for the **RPi-Monitor** project. Today, I created a GitHub organization so volunteers can join the project, contribute, and help ensure it keeps going.

--- 

![RPi-Monitor logo](docs/source/_static/logo.png)

# Overview

**RPi-Monitor** is an application designed to perform real time monitoring embedded devices.

The development platform is a [Raspberry Pi](http://raspberrypi.org) B.

**RPi-Monitor** provides a lot of feature such as **Embedded Web server**, **Alert messaging**, **SNMP integration**...

For details, refer to [keys features of RPi-Monitor](https://xavierberger.github.io/RPi-Monitor-docs/01_features.html) in documentation.

# Screenshots

![MainPage](docs/source/_static/features002.png)

See [Screenshots](https://xavierberger.github.io/RPi-Monitor-docs/02_screenshots.html) chapter
of documentation to see more screenshots.

# Installation

## Quick installation

RPi-Monitor can be installed or updated directly from the command line using the installation script. The script downloads the appropriate release from GitHub, verifies its SHA-256 checksum, and installs or updates RPi-Monitor.

On supported Debian-based systems, run:

```bash
curl -fsSL https://raw.githubusercontent.com/RPi-Monitor/RPi-Monitor/feat/update_packaging_and_installation/install.sh | sudo bash
```

This command downloads and executes the installation script without requiring a manual download.

**Requirements:**
- A supported Debian-based system: Debian, Raspberry Pi OS (Raspbian), or Ubuntu.
- `curl`, `jq`, and `unzip`. The script checks for these tools and reports any missing dependencies.
- Root privileges, provided here by `sudo`.
- An interactive terminal to confirm the installation, unless `--yes` is specified.

The script automatically selects the latest stable release by default. If RPi-Monitor is already installed using this script, it updates the existing installation and preserves its configuration.

> **Important:** The script must be executed with Bash. Do not replace `bash` with `sh`, as the script uses Bash-specific syntax. The script also refuses to run if RPi-Monitor is still installed through the Debian package; remove that package first with `sudo apt remove rpimonitor`. Your configuration in `/etc/rpimonitor` is kept.

For more information, see the [installation documentation](https://xavierberger.github.io/RPi-Monitor-docs/11_installation.html).

## Installation options

The installation script supports options to select a release, automate confirmation, simulate an installation, and customize service management.

<details>
<summary>Show all installation options</summary>

The options can be passed after the script URL by using `bash -s --`:

```bash
curl -fsSL https://raw.githubusercontent.com/RPi-Monitor/RPi-Monitor/feat/update_packaging_and_installation/install.sh | sudo bash -s -- --help
```

### Available options

| Option | Description |
| --- | --- |
| `-h`, `--help` | Display the available options and exit. |
| `-y`, `--yes` | Automatically confirm the operation. Required when running without an interactive terminal. |
| `--version VERSION` | Install a specific published release, for example `--version 2.14`. The optional leading `v` is accepted. |
| `--pre-release` | Select the newest published release, including pre-releases. Pre-releases may not be stable. |
| `--force` | Force installation or reinstallation even if the installed version is already up to date. |
| `--dry-run` | Simulate the installation or update without applying the system changes. Root privileges are still required. |
| `--no-service` | Skip systemd service management. The script will not enable, start, or restart the service. |

### Examples

**Install the latest stable release and confirm interactively:**

```bash
curl -fsSL https://raw.githubusercontent.com/RPi-Monitor/RPi-Monitor/feat/update_packaging_and_installation/install.sh | sudo bash
```

**Install a specific release:**

```bash
curl -fsSL https://raw.githubusercontent.com/RPi-Monitor/RPi-Monitor/feat/update_packaging_and_installation/install.sh | sudo bash -s -- --version 2.14
```

**Install the newest release, including pre-releases:**

```bash
curl -fsSL https://raw.githubusercontent.com/RPi-Monitor/RPi-Monitor/feat/update_packaging_and_installation/install.sh | sudo bash -s -- --pre-release
```

**Run without an interactive confirmation:**

```bash
curl -fsSL https://raw.githubusercontent.com/RPi-Monitor/RPi-Monitor/feat/update_packaging_and_installation/install.sh | sudo bash -s -- --yes
```

**Simulate an installation or update:**

```bash
curl -fsSL https://raw.githubusercontent.com/RPi-Monitor/RPi-Monitor/feat/update_packaging_and_installation/install.sh | sudo bash -s -- --dry-run
```

**Force reinstallation of the current version:**

```bash
curl -fsSL https://raw.githubusercontent.com/RPi-Monitor/RPi-Monitor/feat/update_packaging_and_installation/install.sh | sudo bash -s -- --force
```

**Install without managing the systemd service:**

```bash
curl -fsSL https://raw.githubusercontent.com/RPi-Monitor/RPi-Monitor/feat/update_packaging_and_installation/install.sh | sudo bash -s -- --no-service
```

Options can be combined. For example, to install a specific version automatically without managing the service:

```bash
curl -fsSL https://raw.githubusercontent.com/RPi-Monitor/RPi-Monitor/feat/update_packaging_and_installation/install.sh | sudo bash -s -- --version 2.14 --yes --no-service
```

### Custom deployment root

The `TARGET_DIR` environment variable allows the files to be deployed under an alternative root directory. This is useful for testing or preparing a filesystem image.

For example:

```bash
sudo TARGET_DIR=/tmp/rpi-root bash ./install.sh --dry-run
```

**Note:** `TARGET_DIR` changes the destination of deployed files, but does not isolate system-level operations such as package management. Use it with care.

</details>

Each release can also be installed with a Debian package for **Raspbian**.

For other (unsupported) distribution (such as Gentoo, ArchLinux) refer to [Custom installation](https://xavierberger.github.io/RPi-Monitor-docs/12_custom_installation.html) chapter of documentation.

# Documentation

If you want to install, use or customize **RPi-Monitor** refer to [documentation](https://xavierberger.github.io/RPi-Monitor-docs/index.html)

If you want to see example of configuration and see what **RPi-Monitor** can do, refer to
[RPi-Monitor Usages](https://xavierberger.github.io/RPi-Monitor-docs/30_index.html).

Frequently Asked Question find answer into the [FAQ](https://xavierberger.github.io/RPi-Monitor-docs/14_faq.html) page.

# Development

If you want to participate and propose a pull request, refer to [contributing](https://xavierberger.github.io/RPi-Monitor-docs/41_contributing.html) chapter of documentation.

**Note**: Pull request perfomed on **develop** branch will be integrated as soon as possible. Pull request perform on master branche may only be integrated when a new version is published (or not may not be integrated at all...)

# News / License

**Latest news** : [RPi-Experience Blog](http://rpi-experiences.blogspot.fr/)

**License**: [GPLv3](LICENSE)
