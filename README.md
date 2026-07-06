# libfprint-0c72

Patched libfprint for **ELAN 04f3:0c72** fingerprint sensor (Acer Swift 3, 2023).

## Problem

The ELAN 0c72 is a tiny swipe sensor (150x52 pixels). The original libfprint uses Bozorth3 minutiae matching with threshold 24, which is too strict for such small images. This causes frequent authentication failures even with properly enrolled fingerprints.

## Solution

Two patches to `libfprint/drivers/elan.c` and `elan.h`:

| Parameter | Original | Patched | Purpose |
|-----------|----------|---------|---------|
| `bz3_threshold` | 24 | 12 | More lenient matching for small images |
| `ELAN_MAX_FRAMES` | 30 | 50 | Capture more frames during swipe for larger assembled image |

## Quick Install

```bash
sudo ./install.sh
```

## Manual Install

```bash
# Install dependencies (Debian/Ubuntu)
sudo apt install build-essential meson ninja-build python3-dev libglib2.0-dev libusb-1.0-0-dev libgusb-dev libudev-dev

# Build
meson setup builddir
ninja -C builddir

# Install
sudo ninja -C builddir install
sudo ldconfig
sudo systemctl restart fprintd
```

## Test

```bash
fprintd-enroll
fprintd-verify
```

## Device Info

- **Sensor**: ELAN 04f3:0c72
- **Type**: Swipe (150x52 px)
- **Protocol**: Old ELAN (no MOC2 - no EP 0x84)
- **Laptop**: Acer Swift 3 SF314-43 (2023)

## Based On

- [SilverCondor18/libfprint](https://github.com/SilverCondor18/libfprint) - adds 0c72 to device table
- Original libfprint from freedesktop.org
