# 🔨 Custom Parrot OS ISO Build Plan

This document outlines all required specifications, configurations, and tasks for creating a fully automated and customized Parrot OS ISO using `parrot-iso-build`.

---

## ✅ Goals

* Produce a Parrot OS ISO that:

  * Uses a specific disk layout and partitions automatically
  * Installs a predefined set of custom `.deb` packages on first boot
  * Adds system utilities and browser extensions
  * Configures GPG keys for GitHub commit signing
  * Installs Python and bash utility scripts into `~/scripts/`
  * Sets timezone and NTP correctly
  * Sets a custom desktop wallpaper by default
  * Applies a specific desktop theme appearance
  * Creates development and encryption-related folders (`~/workspace`, `~/veracrypt`)
  * Applies shell preferences and Git identity automatically
  * Captures logs of first-boot installation tasks
  * Adds safety mechanisms for idempotent first-boot logic

---

## 📁 User Configuration

* **Username:** `foo`
* **Password:** `g2monkey` (hardcoded)
* **Groups:** `sudo` (added to allow administrative privileges)

---

## 📜 Partition Layout (Autonomous Setup)

| Mount Point | Device           | Size      | File System  | Flags       |
| ----------- | ---------------- | --------- | ------------ | ----------- |
| /boot/efi   | `/dev/nvme1n1p1` | 300 MiB   | `fat32`      | `boot, esp` |
| /, /home    | `/dev/nvme1n1p2` | 1.75 TiB  | `btrfs`      | -           |
| swap        | `/dev/nvme1n1p3` | 68.76 GiB | `linux-swap` | `swap`      |

A `preseed.cfg` file located at `auto/config/preseed.cfg` is used with partman-auto to enforce this layout.

---

## 🌐 Timezone & Networking

* **Timezone:** `Asia/Bangkok`
* **NTP:** Enabled
* **RTC:** UTC (not local time)

```bash
sudo timedatectl set-timezone Asia/Bangkok
sudo systemctl restart systemd-timesyncd
sudo timedatectl set-ntp on
```

---

## 🔐 GPG Keys (Trusted on First Boot)

### GitHub Signing Key:

```
[PGP PUBLIC KEY BLOCK for unattributed]
```

### Personal Identity Key:

```
[PGP PUBLIC KEY BLOCK for Duncan/BlackBagSecurity]
```

* Keys must be trusted and pre-imported
* Git config should support commit signing post-install

---

## 🖼 Default Desktop Background

* Set to: `Elephants_5640x3172.jpg`
* File path: `/usr/share/backgrounds/mate/abstract/Elephants_5640x3172.jpg`
* Applied via `setup-theme.sh` at first boot

---

## 😕 Desktop Theme Appearance

* GTK Theme: `BlackMATE`
* Window Manager Theme: `BlackMATE`
* Icon Theme: `mate`
* Font: `Cantarell 11`

These are applied by `/usr/local/bin/setup-theme.sh` via gsettings using systemd.

---

## 📁 Scripts Directory

* Location: `~/scripts/`
* Must include non-packaged `*.py` and `*.sh` scripts from:

  * `/home/foo/workspace/parrot-os-modifications/scripts/`

### Script Tree:

```
scripts/
├── install_nvidia.py
├── keys
│   ├── import_gpg_keys.sh
│   ├── publickey.duncan@blackbagsecurity.com-6f97b79b5f189e7f421a4c667f60a5b61df975b6.asc
│   └── publickey.shopkeeper@unattributed.blog-d633e67f12a12a9c3dc410965ff509dca27b26e0.asc
├── setup_brave.py
├── setup_configure_gpg.py
├── setup_edge.py
├── setup_nvidia.py
├── setup_protonpass.py
├── setup_protonvpn_extension.py
├── setup-signal.py
├── setup_touchpad_watcher.py
├── setup_veracrypt.py
├── setup_vscode_insiders.py
├── setup_vscode.py
└── VS_Code_Insiders_extensions.py
```

* Create the following additional directories as part of ISO provisioning:

  * `~/workspace`
  * `~/veracrypt`

---

## 📦 Custom `.deb` Packages (Installed on First Boot via systemd)

Each has its own systemd one-shot installer:

* `setup-nvidia.deb`
* `setup-edge.deb`
* `setup-signal.deb`
* `setup-vscode.deb`
* `setup-brave.deb`

Installed and triggered via:

```bash
sudo systemctl enable setup-<name>.service
```

---

## 📜 Additional APT Sources

```bash
echo "deb http://deb.debian.org/debian bookworm-backports main" \
  | sudo tee /etc/apt/sources.list.d/backports.list

sudo apt update
sudo apt install -t bookworm-backports systemd systemd-timesyncd
```

---

## 🗓 Additional Packages (From Lory or Backports)

```bash
sudo apt install -y \
  kde-cli-tools ntp ntpdate gh xinput joe gpg \
  pinentry-gtk2 pinentry-curses dirmngr seahorse \
  devscripts virtualbox apt-transport-https \
  ca-certificates curl software-properties-common libsecret-1-0 libsecret-1-dev
```

---

## 🔐 Manual Software Post-Install (Not ISO-packed)

* **ProtonPass** browser extension (install manually post-boot)
* **Veracrypt** (to be manually installed by user)

---

## 🚀 First-Boot Behavior (Orchestrated)

Executed automatically after ISO boots:

1. Full system update:

```bash
sudo apt update && sudo apt full-upgrade -y && sudo apt autoremove -y
```

2. All `.deb` packages installed silently
3. All custom services execute once via systemd
4. GPG keys trusted
5. Scripts directory created and populated
6. `~/workspace` and `~/veracrypt` directories created
7. Timezone set:

```bash
sudo timedatectl set-timezone Asia/Bangkok
sudo systemctl restart systemd-timesyncd
sudo timedatectl set-ntp on
```

8. Desktop background set to `Elephants_5640x3172.jpg`
9. Desktop appearance theme set to BlackMATE (GTK + WM), icons: `mate`, font: `Cantarell 11`
10. User `foo` pre-added to `sudo` group
11. Shell preferences applied:
    * Git identity preset with GPG signing
    * Dotfiles (`.bashrc`, `.profile`, `.gitconfig`, etc.) installed if available
12. Unattended upgrades enabled
13. First-boot system logs collected to `/var/log/setup-*.log`
14. Completion flag created at `/var/log/custom-iso-setup.done`
15. One-shot services built with `ConditionFirstBoot=yes` and `SuccessExitStatus=0`
16. Firewall configuration using `ufw`:

```bash
sudo apt install -y ufw
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw enable
```

17. Monitoring tools:

```bash
sudo apt install -y htop btop lm-sensors sysstat ncdu
```

---

## 🧪 QEMU Testing Environment

Custom ISOs are tested in a virtualized QEMU environment to validate installation, first-boot behavior, and provisioning correctness.

### Launch Script: `run-qemu.sh`
```bash
#!/bin/bash
set -e

ISO="images/Parrot-home-6.0_amd64.iso"
DISK="parrot-test-disk.qcow2"

# Create disk image if missing
if [ ! -f "$DISK" ]; then
    qemu-img create -f qcow2 "$DISK" 64G
fi

qemu-system-x86_64 \
  -enable-kvm \
  -m 8192 \
  -smp cpus=8,sockets=1,cores=4,threads=2 \
  -cpu host \
  -machine q35,accel=kvm \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE.fd \
  -drive if=pflash,format=raw,file=/usr/share/OVMF/OVMF_VARS.fd \
  -cdrom "$ISO" \
  -drive file="$DISK",format=qcow2,if=virtio \
  -display sdl,gl=on \
  -vga virtio \
  -boot d \
  -nic user
```

The script is located in `~/workspace/custom_parrot_iso/run-qemu.sh` and provides:
- UEFI boot support via OVMF
- 8 GB RAM and 8 vCPUs
- virtio drivers for disk and display
- SDL window with OpenGL

---

## 📦 Tools Used

* `parrot-iso-build` (custom fork at `/home/foo/workspace/unattributed-parrot-iso-build/build.sh`)
  - Includes modifications not present in `main`, such as structured logging, ISO verification, and custom provisioning logic
* `systemd` one-shot services for delayed install
* `fakeroot dpkg-deb` to build `.deb` packages
* `lintian` for validating `.deb` integrity
