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
| `IMG_ENROLL_STAGES` | 5 | 8 | More samples per template — tolerates imperfect swipes during verify |
| Stop-cmd error handling | session error | ignored | A failed post-stage stop command no longer aborts enrollment (was reported as `enroll-disconnected`) |
| Pre-calibration delay | 0 | 150ms | Let the sensor settle after stop command before recalibrating |

Note: `IMG_ENROLL_STAGES` lives in `libfprint/fp-image-device-private.h` (affects all image drivers), the rest is in `libfprint/drivers/elan.c` / `elan.h`.

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

## Important: Protect From apt Upgrades

The patched library overwrites `/usr/lib/.../libfprint-2.so.2.0.0`, which is owned by the `libfprint-2-2` package. A regular system upgrade will silently replace it with the stock library and all the problems will return. Prevent that:

```bash
sudo apt-mark hold libfprint-2-2
```

(Or use `dpkg-divert` if you prefer apt to keep updating the package itself.) When a new upstream libfprint version arrives, rebase the patches, rebuild, reinstall, then `apt-mark unhold` → upgrade → re-hold.

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

Or run `sudo ./fix-pam.sh` to apply it automatically.

## Troubleshooting

**`enroll-disconnected` during enrollment** — fixed by the stop-command patch above; make sure you are running the patched library (rebuild + `sudo ninja -C builddir install && sudo ldconfig && sudo systemctl restart fprintd`).

**`Device was already claimed`** — another process holds the sensor. Close the GNOME Settings fingerprint page (or any other enrollment UI) before using `fprintd-enroll` from the terminal.

**Debugging** — stop the daemon and run it in the foreground with verbose logs:

```bash
sudo systemctl stop fprintd
sudo G_MESSAGES_DEBUG=all /usr/libexec/fprintd -t
```

Then run `fprintd-enroll` in another terminal. Match scores appear as `score N/6` lines; USB retries as `capture USB error, retry ...`.

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
