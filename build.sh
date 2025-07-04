#!/bin/bash

set -euo pipefail

# ─── COLORS ─────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[1;34m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC}   $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ─── CONFIG ─────────────────────────────────────
PARROT_DIST="lory"
PARROT_VERSION="6.0"
PARROT_VARIANT="default"
IMAGE_TYPE="live"
TARGET_DIR="$(dirname "$0")/images"
TARGET_SUBDIR=""
SUDO="sudo"
VERBOSE=""
DEBUG=""
HOST_ARCH=$(dpkg --print-architecture)
ACTION="${ACTION:-}"  # Prevent unbound var

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_LOG="$SCRIPT_DIR/build.log"
AUTO_CHROOT="$1/auto/config/includes.chroot"

# ─── INIT ───────────────────────────────────────
: > "$BUILD_LOG"
info "Logging to $BUILD_LOG"

# ─── FUNCTIONS ──────────────────────────────────
image_name() {
	case "$IMAGE_TYPE" in
		live) echo "live-image-$PARROT_ARCH.hybrid.iso" ;;
		installer)
			if [ "$PARROT_VARIANT" = "netinst" ]; then
				echo "architect/images/parrot-$PARROT_VERSION-$PARROT_ARCH-NETINST-1.iso"
			else
				echo "architect/images/parrot-$PARROT_VERSION-$PARROT_ARCH-DVD-1.iso"
			fi
		;;
	esac
}

target_image_name() {
	local arch=$1
	IMAGE_NAME="$(image_name $arch)"
	IMAGE_EXT="${IMAGE_NAME##*.}"
	[ "$IMAGE_EXT" = "$IMAGE_NAME" ] && IMAGE_EXT="img"
	if [ "$IMAGE_TYPE" = "live" ]; then
		if [ "$PARROT_VARIANT" = "default" ]; then
			echo "${TARGET_SUBDIR:+$TARGET_SUBDIR/}Parrot-home-${PARROT_VERSION}_$PARROT_ARCH.$IMAGE_EXT"
		else
			echo "${TARGET_SUBDIR:+$TARGET_SUBDIR/}Parrot-$PARROT_VARIANT-${PARROT_VERSION}_$PARROT_ARCH.$IMAGE_EXT"
		fi
	else
		echo "${TARGET_SUBDIR:+$TARGET_SUBDIR/}Parrot-architect-${PARROT_VERSION}_$PARROT_ARCH.$IMAGE_EXT"
	fi
}

target_build_log() {
	TARGET_IMAGE_NAME=$(target_image_name "$1")
	echo "${TARGET_IMAGE_NAME%.*}.log"
}

run_and_log() {
	info "$*"
	if ! "$@" 2>&1 | tee -a "$BUILD_LOG"; then
		error "Command failed: $*"
		exit 1
	fi
}

clean() {
	info "🧹 Cleaning previous build..."
	run_and_log $SUDO lb clean --purge
	run_and_log $SUDO rm -rf "$(pwd)/architect/tmp" "$(pwd)/architect/debian-cd"
}

verify_customizations() {
	info "🔍 Verifying embedded customizations..."

# Check debs
	if compgen -G "$AUTO_CHROOT/root/debs/*.deb" >/dev/null; then
		echo -e "\n📦 Custom .deb files:" | tee -a "$BUILD_LOG"
		ls -1 "$AUTO_CHROOT"/root/debs/*.deb | tee -a "$BUILD_LOG"
	else
		echo "⚠️  No custom debs found in /root/debs/" | tee -a "$BUILD_LOG"
	fi

# Check services
	if compgen -G "$AUTO_CHROOT/etc/systemd/system/*.service" >/dev/null; then
		echo -e "\n🛠 Systemd services:" | tee -a "$BUILD_LOG"
		ls -1 "$AUTO_CHROOT"/etc/systemd/system/*.service | tee -a "$BUILD_LOG"
	fi

# Check scripts
	if [ -d "$AUTO_CHROOT/home/foo/scripts" ]; then
		echo -e "\n📁 Scripts to be included:" | tee -a "$BUILD_LOG"
		find "$AUTO_CHROOT/home/foo/scripts" -type f | tee -a "$BUILD_LOG"
	fi

# Final note
	success "All custom content detected and ready for ISO"
}

summarize_packages() {
	echo -e "\n📝 ISO PACKAGE SUMMARY" | tee -a "$BUILD_LOG"
	echo "----------------------------" | tee -a "$BUILD_LOG"
	echo "✔️  Base Parrot OS system: will be included via live-build."

	# From repo
	if grep -r "apt install" "$AUTO_CHROOT"/*.sh "$AUTO_CHROOT"/usr/local/bin/*.sh 2>/dev/null | grep -v "/root/debs" | grep -v setup-*.deb > /tmp/repo-pkgs.txt; then
		echo -e "\n📦 Additional .deb from Parrot repositories:" | tee -a "$BUILD_LOG"
		grep -oP '(?<=apt install -y )[^&|;]+' /tmp/repo-pkgs.txt | tr ' ' '\n' | sort -u | tee -a "$BUILD_LOG"
	fi

	# Custom
	if compgen -G "$AUTO_CHROOT/root/debs/*.deb" >/dev/null; then
		echo -e "\n🔧 Custom .deb packages:" | tee -a "$BUILD_LOG"
		ls "$AUTO_CHROOT"/root/debs/*.deb | sed 's|.*/||' | tee -a "$BUILD_LOG"
	fi
}

# ─── ARG PARSE (based on original logic) ────────
. "$SCRIPT_DIR/.getopt.sh"
temp=$(getopt -o "$BUILD_OPTS_SHORT" -l "$BUILD_OPTS_LONG,get-image-path" -- "$@")
eval set -- "$temp"
while true; do
	case "$1" in
		-d|--distribution) PARROT_DIST="$2"; shift 2 ;;
		-a|--arch) PARROT_ARCH="$2"; shift 2 ;;
		-v|--verbose) VERBOSE="1"; shift ;;
		-D|--debug) DEBUG="1"; shift ;;
		--variant) PARROT_VARIANT="$2"; shift 2 ;;
		--version) PARROT_VERSION="$2"; shift 2 ;;
		--subdir) TARGET_SUBDIR="$2"; shift 2 ;;
		--get-image-path) ACTION="get-image-path"; shift ;;
		--clean) ACTION="clean"; shift ;;
		--no-clean) NO_CLEAN="1"; shift ;;
		--) shift; break ;;
		*) error "Unknown option: $1"; exit 1 ;;
	esac
done

PARROT_ARCH="${PARROT_ARCH:-$HOST_ARCH}"
[[ "$PARROT_ARCH" == "x64" ]] && PARROT_ARCH="amd64"
[[ "$PARROT_ARCH" == "x86" ]] && PARROT_ARCH="i386"

[[ "$ACTION" == "get-image-path" ]] && echo "$(target_image_name $PARROT_ARCH)" && exit 0
[[ "${NO_CLEAN:-}" != "1" ]] && clean
[[ "$ACTION" == "clean" ]] && exit 0

cd "$SCRIPT_DIR"
mkdir -p "$TARGET_DIR/$TARGET_SUBDIR"

# ─── BUILD ──────────────────────────────────────
info "⚙️  Configuring live-build..."
run_and_log lb config -a "$PARROT_ARCH" --distribution "$PARROT_DIST" -- --variant "$PARROT_VARIANT" --version "$PARROT_VERSION"

info "🏗 Building ISO..."
run_and_log $SUDO lb build

verify_customizations
summarize_packages

# ─── FINAL OUTPUT ───────────────────────────────
ISO_OUT="$(image_name)"
FINAL_ISO="$TARGET_DIR/$(target_image_name $PARROT_ARCH)"
run_and_log mv -f "$ISO_OUT" "$FINAL_ISO"
run_and_log mv -f "$BUILD_LOG" "$TARGET_DIR/$(target_build_log $PARROT_ARCH)"

success "✅ ISO build completed"
info "📦 ISO: $FINAL_ISO"
info "📄 Log: $TARGET_DIR/$(target_build_log $PARROT_ARCH)"
