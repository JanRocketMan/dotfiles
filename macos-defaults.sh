#!/usr/bin/env bash
set -euo pipefail

# macos-defaults.sh — Apply preferred macOS system defaults.
# Run once on a fresh Mac (or after a reset). Requires logout/restart for
# some settings to take effect.

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "error: this script is for macOS only" >&2
    exit 1
fi

echo "=== Applying macOS defaults ==="

# ── Trackpad ─────────────────────────────────────────────────────────────────

# Tap to click
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true

# ── Menu bar ─────────────────────────────────────────────────────────────────

# Show battery percentage
defaults write com.apple.menuextra.battery ShowPercent -string "YES"

# ── Windows & Spaces ─────────────────────────────────────────────────────────

# Don't minimize on double-click
defaults write -g AppleMiniaturizeOnDoubleClick -bool false

# Don't auto-switch to a Space with open windows for an app
defaults write -g AppleSpacesSwitchOnActivate -bool false

# ── Finder ───────────────────────────────────────────────────────────────────

# Show all file extensions
defaults write -g AppleShowAllExtensions -bool true

# ── Keyboard ─────────────────────────────────────────────────────────────────

# Fast key repeat
defaults write -g KeyRepeat -int 2

# Disable press-and-hold for accent characters (enable key repeat)
defaults write -g ApplePressAndHoldEnabled -bool false

# ── Text correction ──────────────────────────────────────────────────────────

# Disable all auto-correction / smart substitution
defaults write -g NSAutomaticCapitalizationEnabled -bool false
defaults write -g NSAutomaticDashSubstitutionEnabled -bool false
defaults write -g NSAutomaticPeriodSubstitutionEnabled -bool false
defaults write -g NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write -g NSAutomaticSpellingCorrectionEnabled -bool false

# ── Animations ───────────────────────────────────────────────────────────────

# Disable window open/close animations
defaults write -g NSAutomaticWindowAnimationsEnabled -bool false

echo ""
echo "=== Done ==="
echo "Log out and back in (or restart) for all changes to take effect."
