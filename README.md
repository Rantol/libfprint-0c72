# libfprint-0c72

Patched libfprint for **ELAN 04f3:0c72** fingerprint sensor (Acer Swift 3, 2023).

## Problem

The ELAN 0c72 is a tiny swipe sensor (150x52 pixels). The original libfprint uses Bozorth3 minutiae matching with threshold 24, which is too strict for such small images. This causes frequent authentication failures even with properly enrolled fingerprints.

Additionally, on newer kernels (6.12.94+) the sensor is prone to USB transfer errors during multi-stage operations (enrollment, repeated verification), causing the driver to disconnect.

## Solution

Patches to `libfprint/drivers/elan.c` and `elan.h`:

| Parameter | Original | Patched | Purpose |
|-----------|----------|---------|---------|
| `bz3_threshold` | 24 | 6 | More lenient matching for small images |
| `ELAN_MAX_FRAMES` | 30 | 50 | Capture more frames during swipe for larger assembled image |
| `ELAN_MIN_FRAMES` | 7 | 5 | Allow shorter swipes |
| `ELAN_CMD_TIMEOUT` | 10000 | 15000 | Longer USB command timeout for slow responses |
| `ELAN_FINGER_TIMEOUT` | 200 | 1000 | More time between frames during capture |
| Capture retries | 0 | 3 | Retry on USB errors with 50ms delay |
| Calibrate retries | 0 | 3 | Retry on calibration USB errors with 100ms delay |

## Important: Power Management

The ELAN 0c72 is sensitive to USB autosuspend. If TLP or PowerTOP is enabled, add this to `/etc/tlp.conf`:

```
USB_DENYLIST="04f3:0c72"
```

If using PowerTOP's `--auto-tune`, disable autosuspend for the sensor after it runs:

```bash
for d in /sys/bus/usb/devices/*/idVendor; do
    vid=$(cat "$d" 2>/dev/null)
    [ "$vid" = "04f3" ] && echo on > "$(dirname "$d")/power/control" 2>/dev/null
done
```

## Important: Re-enroll After Update

After rebuilding and installing the library, **always re-enroll fingerprints**:

```bash
fprintd-enroll
```

Old fingerprints may not match the new capture parameters.

## Important: PAM Configuration

For system authentication (sudo, login) to work with fingerprint, ensure `/etc/pam.d/common-auth` has adequate timeout:

```
auth    [success=2 default=ignore]    pam_fprintd.so max-tries=3 timeout=30
```

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
