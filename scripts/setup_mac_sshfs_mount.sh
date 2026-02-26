#!/usr/bin/env bash
# =============================================================================
# setup_mac_sshfs_mount.sh
# Run this ONCE on your Mac to permanently mount:
#
#   sweeden@login.hpcc.ttu.edu:/lustre/work/sweeden/14GPARTFOUR  (remote)
#   →  /Volumes/14GPARTFOUR   (local macOS mountpoint)
#
# After setup, the mount auto-reconnects on login via a LaunchAgent plist.
#
# Requirements (installed by this script if missing):
#   - Homebrew  (https://brew.sh)
#   - macFUSE   (brew install --cask macfuse)
#   - sshfs     (brew install --cask sshfs)
#
# Usage:
#   bash setup_mac_sshfs_mount.sh          # interactive first-time setup
#   bash setup_mac_sshfs_mount.sh --mount  # mount now (VPN must be active)
#   bash setup_mac_sshfs_mount.sh --umount # unmount
#   bash setup_mac_sshfs_mount.sh --verify # check mount and list contents
# =============================================================================

set -euo pipefail

HPCC_USER="sweeden"
HPCC_HOST="login.hpcc.ttu.edu"
REMOTE_PATH="/lustre/work/sweeden/14GPARTFOUR"
LOCAL_MOUNT="/Volumes/14GPARTFOUR"
SSH_KEY="${HOME}/.ssh/id_rsa"
PLIST_NAME="com.ttu.hpcc.sshfs.sweeden"
PLIST_PATH="${HOME}/Library/LaunchAgents/${PLIST_NAME}.plist"

MODE="${1:---setup}"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
info()  { echo "  ✓  $*"; }
warn()  { echo "  ⚠  $*" >&2; }
error() { echo "  ✗  $*" >&2; exit 1; }

require_macos() {
    [[ "$(uname)" == "Darwin" ]] || error "This script must run on macOS."
}

# ---------------------------------------------------------------------------
# Mount now
# ---------------------------------------------------------------------------
do_mount() {
    if mount | grep -q "${LOCAL_MOUNT}"; then
        info "Already mounted at ${LOCAL_MOUNT}"
        return 0
    fi

    mkdir -p "${LOCAL_MOUNT}"

    echo "Mounting ${HPCC_USER}@${HPCC_HOST}:${REMOTE_PATH} → ${LOCAL_MOUNT} ..."
    sshfs \
        "${HPCC_USER}@${HPCC_HOST}:${REMOTE_PATH}" \
        "${LOCAL_MOUNT}" \
        -o IdentityFile="${SSH_KEY}" \
        -o reconnect \
        -o ServerAliveInterval=15 \
        -o ServerAliveCountMax=3 \
        -o allow_other \
        -o volname="lustre-sweeden" \
        -o follow_symlinks \
        -o auto_cache \
        -o uid="$(id -u)" \
        -o gid="$(id -g)" \
        && info "Mount successful: ${LOCAL_MOUNT}" \
        || error "sshfs mount failed. Is the VPN active? Is macFUSE installed?"
}

# ---------------------------------------------------------------------------
# Unmount
# ---------------------------------------------------------------------------
do_umount() {
    if ! mount | grep -q "${LOCAL_MOUNT}"; then
        info "Not currently mounted."
        return 0
    fi
    umount "${LOCAL_MOUNT}" 2>/dev/null \
        || diskutil unmount force "${LOCAL_MOUNT}" 2>/dev/null \
        || error "Could not unmount ${LOCAL_MOUNT}"
    info "Unmounted ${LOCAL_MOUNT}"
}

# ---------------------------------------------------------------------------
# Install dependencies
# ---------------------------------------------------------------------------
install_deps() {
    echo ""
    echo "=== Checking dependencies ==="

    if ! command -v brew &>/dev/null; then
        echo "Homebrew not found — installing..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    else
        info "Homebrew already installed"
    fi

    if ! system_profiler SPExtensionsDataType 2>/dev/null | grep -q "macFUSE"; then
        echo "macFUSE not found — installing (requires admin password)..."
        brew install --cask macfuse
        warn "macFUSE installed. You may need to approve the kernel extension in:"
        warn "  System Settings → Privacy & Security → Allow kernel extension"
        warn "Then re-run this script."
    else
        info "macFUSE already installed"
    fi

    if ! command -v sshfs &>/dev/null; then
        echo "sshfs not found — installing..."
        brew install --cask sshfs
    else
        info "sshfs already installed ($(sshfs --version 2>&1 | head -1))"
    fi
}

# ---------------------------------------------------------------------------
# Create LaunchAgent for persistent auto-mount on login
# ---------------------------------------------------------------------------
install_launchagent() {
    echo ""
    echo "=== Installing LaunchAgent for persistent mount ==="

    mkdir -p "$(dirname "${PLIST_PATH}")"

    cat > "${PLIST_PATH}" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${PLIST_NAME}</string>

    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>-c</string>
        <string>
            # Wait for VPN / network
            sleep 8
            mkdir -p "${LOCAL_MOUNT}"
            /usr/local/bin/sshfs \\
                ${HPCC_USER}@${HPCC_HOST}:${REMOTE_PATH} \\
                ${LOCAL_MOUNT} \\
                -o IdentityFile=${SSH_KEY} \\
                -o reconnect \\
                -o ServerAliveInterval=15 \\
                -o ServerAliveCountMax=3 \\
                -o volname=lustre-sweeden \\
                -o follow_symlinks \\
                -o auto_cache \\
                -o uid=$(id -u) \\
                -o gid=$(id -g)
        </string>
    </array>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <false/>

    <key>StandardOutPath</key>
    <string>${HOME}/Library/Logs/${PLIST_NAME}.log</string>

    <key>StandardErrorPath</key>
    <string>${HOME}/Library/Logs/${PLIST_NAME}.err</string>
</dict>
</plist>
PLIST

    launchctl unload "${PLIST_PATH}" 2>/dev/null || true
    launchctl load -w "${PLIST_PATH}"
    info "LaunchAgent installed: ${PLIST_PATH}"
    info "The mount will auto-start on next login (after VPN connects)."
    echo ""
    echo "To control the agent manually:"
    echo "  Start:  launchctl start ${PLIST_NAME}"
    echo "  Stop:   launchctl stop  ${PLIST_NAME}"
    echo "  Remove: launchctl unload ${PLIST_PATH} && rm ${PLIST_PATH}"
}

# ---------------------------------------------------------------------------
# Verify mount and show contents
# ---------------------------------------------------------------------------
verify() {
    echo ""
    echo "=== Verifying mount ==="
    if mount | grep -q "${LOCAL_MOUNT}"; then
        info "Mount active: ${LOCAL_MOUNT}"
        echo ""
        echo "Contents of ${LOCAL_MOUNT}:"
        ls -la "${LOCAL_MOUNT}" 2>/dev/null || warn "ls failed — check VPN / permissions"
    else
        warn "Mount not active. Run:  bash $0 --mount"
    fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
require_macos

case "${MODE}" in
    --mount)   do_mount   ;;
    --umount)  do_umount  ;;
    --verify)  verify     ;;
    --setup)
        echo ""
        echo "╔══════════════════════════════════════════════════════════════╗"
        echo "║  TTU HPCC SSHFS Persistent Mount Setup                      ║"
        echo "║  ${HPCC_USER}@${HPCC_HOST}:${REMOTE_PATH}"
        echo "║  → ${LOCAL_MOUNT}"
        echo "╚══════════════════════════════════════════════════════════════╝"
        echo ""
        echo "Make sure your VPN is active before continuing."
        read -rp "Continue? [y/N] " confirm
        [[ "${confirm}" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }

        install_deps
        do_mount
        install_launchagent
        verify

        echo ""
        echo "✓ Setup complete!"
        echo ""
        echo "The Lustre work directory is now accessible at:"
        echo "  ${LOCAL_MOUNT}"
        echo ""
        echo "Your OLLAMA scripts can reference HPCC files directly, e.g.:"
        echo "  ls ${LOCAL_MOUNT}/CS5474_SOFTWARE_VV/"
        ;;
    *)
        echo "Usage: $0 [--setup | --mount | --umount | --verify]"
        exit 1
        ;;
esac
