# RPi-Monitor — Community Fork, Updated for 2026 & Raspberry Pi OS Bookworm

> **This is a community-maintained fork of the original [RPi-Monitor](https://github.com/XavierBerger/RPi-Monitor) by [Xavier Berger](http://rpi-experiences.blogspot.fr/).**
>
> Xavier built an outstanding self-monitoring tool that served thousands of Raspberry Pi users for nearly a decade. This fork exists to bring it fully up to date with **Raspberry Pi OS Bookworm** (Debian 12, 2023+) and current tooling — so it runs seamlessly on a fresh install with no manual patching.
>
> Fork maintained by: [Htaborda](https://github.com/Htaborda)

---

## What's fixed in this fork

Raspberry Pi OS has changed significantly since RPi-Monitor was last maintained. The following breaking issues have been resolved:

| # | Problem | Fix |
|---|---|---|
| 1 | `apt-key` was removed in Debian 12 (Bookworm) | APT source now uses `/etc/apt/keyrings/rpimonitor.gpg` with `signed-by` |
| 2 | Default `pi` user no longer created by Raspberry Pi OS | Daemon auto-detects: `rpimonitor` → uid 1000 → `nobody` |
| 3 | `aptitude` not installed by default on Bookworm+ | `updatePackagesStatus.pl` now uses `apt-get` |
| 4 | `/boot` moved to `/boot/firmware` on Bookworm | `sdcard.conf` auto-detects the correct boot partition path |
| 5 | `vcgencmd` requires `video` group membership | `install.sh` adds the service user to the `video` group |

**New in this fork:**
- `install.sh` — single-command installer for a fresh Raspberry Pi OS Bookworm install
- `.gitattributes` — enforces LF line endings (shell/Perl scripts break with CRLF on Linux)

---

## Quick Install (Raspberry Pi OS Bookworm+)

On your Raspberry Pi, run:

```bash
git clone https://github.com/Htaborda/RPi-Monitor.git
cd RPi-Monitor
sudo bash install.sh
```

The script installs all dependencies, creates a dedicated `rpimonitor` system user, and starts the service. Once running, open:

```
http://<your-pi-ip>:8888
```

---

## Original README

---

![RPi-Monitor logo](docs/source/_static/logo.png)

# Overview

**RPi-Monitor** is an application designed to perform real time monitoring of embedded devices.

The development platform is a [Raspberry Pi](http://raspberrypi.org) B.

**RPi-Monitor** provides many features such as **Embedded Web server**, **Alert messaging**, **SNMP integration**...

For details, refer to [keys features of RPi-Monitor](https://xavierberger.github.io/RPi-Monitor-docs/01_features.html) in the documentation.

# Screenshots

![MainPage](docs/source/_static/features002.png)

See the [Screenshots](https://xavierberger.github.io/RPi-Monitor-docs/02_screenshots.html) chapter of documentation for more.

# Installation

> **Note:** The original installation method using `apt-key` no longer works on Raspberry Pi OS Bookworm+. Use the `install.sh` script from this fork instead (see above).

For full installation documentation refer to the [getting started](https://xavierberger.github.io/RPi-Monitor-docs/11_installation.html) chapter.

For other distributions (Gentoo, ArchLinux) refer to [Custom installation](https://xavierberger.github.io/RPi-Monitor-docs/12_custom_installation.html).

# Documentation

- Full documentation: [xavierberger.github.io/RPi-Monitor-docs](https://xavierberger.github.io/RPi-Monitor-docs/index.html)
- Configuration examples: [RPi-Monitor Usages](https://xavierberger.github.io/RPi-Monitor-docs/30_index.html)
- FAQ: [xavierberger.github.io/RPi-Monitor-docs/14_faq.html](https://xavierberger.github.io/RPi-Monitor-docs/14_faq.html)

# Development

If you want to contribute a pull request to the **original project**, refer to [contributing](https://xavierberger.github.io/RPi-Monitor-docs/41_contributing.html).

Pull requests for **Bookworm/modern OS compatibility** are welcome on this fork.

# News / License

**Latest news**: [RPi-Experience Blog](http://rpi-experiences.blogspot.fr/)

**License**: [GPLv3](LICENSE)

---

## Original author

**Xavier Berger** built and maintained RPi-Monitor for years. This fork would not exist without his work.

> *"I don't have time to manage updates to `Rpi-Monitor`. The project looks to be used by many people. Some PRs need to be reviewed and merged and the next version is requiring tests. If one of you would like to help to manage the project, I'll be happy to grant her/him rights on the `Rpi-Monitor` repository."*
> — Xavier Berger
