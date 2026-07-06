#!/usr/bin/env bash
# Quick fix: increase fingerprint PAM timeout and retries
set -e
[[ $EUID -ne 0 ]] && { echo "Run with sudo"; exit 1; }

sed -i 's/pam_fprintd.so max-tries=1 timeout=10/pam_fprintd.so max-tries=3 timeout=30/' /etc/pam.d/common-auth
echo "Done. PAM now allows 3 tries with 30s timeout."
