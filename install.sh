#!/bin/bash
# libfprint-0c72 installer for ELAN 0c72 fingerprint sensor
# Supports: Debian/Ubuntu, Arch, Fedora

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[-]${NC} $1"; exit 1; }

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "Run with sudo: sudo ./install.sh"
    fi
}

detect_distro() {
    if [ -f /etc/debian_version ]; then
        DISTRO="debian"
        PKG_INSTALL="apt-get install -y"
        PKG_UPDATE="apt-get update"
        BUILD_DEPS="build-essential meson ninja-build python3-dev libglib2.0-dev libusb-1.0-0-dev libgusb-dev libudev-dev python3-pyusb git"
    elif [ -f /etc/arch-release ]; then
        DISTRO="arch"
        PKG_INSTALL="pacman -S --noconfirm"
        PKG_UPDATE=""
        BUILD_DEPS="base-devel meson ninja python-glib libusb gusb systemd git"
    elif [ -f /etc/fedora-release ]; then
        DISTRO="fedora"
        PKG_INSTALL="dnf install -y"
        PKG_UPDATE=""
        BUILD_DEPS="gcc make meson ninja-build python3-devel glib2-devel libusb1-devel libgusb-devel systemd-devel git"
    else
        error "Unsupported distribution. Install manually: see README.md"
    fi
    log "Detected: $DISTRO"
}

install_deps() {
    log "Installing build dependencies..."
    if [ -n "$PKG_UPDATE" ]; then
        $PKG_UPDATE
    fi
    $PKG_INSTALL $BUILD_DEPS
}

build() {
    log "Building libfprint..."
    cd "$(dirname "$0")"

    rm -rf builddir
    meson setup builddir
    ninja -C builddir
}

install_lib() {
    log "Installing libfprint..."
    ninja -C builddir install
    ldconfig
}

restart_fprintd() {
    log "Restarting fprintd..."
    systemctl restart fprintd 2>/dev/null || true
}

verify() {
    log "Verifying installation..."
    if fprint-list-supported-devices 2>/dev/null | grep -q "0c72"; then
        log "ELAN 0c72 is supported!"
    else
        warn "Could not verify device support"
    fi
}

main() {
    check_root
    detect_distro
    install_deps
    build
    install_lib
    restart_fprintd
    verify
    echo ""
    log "Installation complete!"
    log "Test with: fprintd-enroll && fprintd-verify"
}

main "$@"
