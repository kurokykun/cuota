#!/usr/bin/env bash
# Prepares the third-party native pieces of the Android app:
#   - cntlm 0.94.1, built from source with the NDK as jniLibs/<abi>/libcntlm.so.
#     Android only allows executing binaries installed as native libraries.
#   - hev-socks5-tunnel 2.19.3, its prebuilt AAR into app/libs.
# Downloads from GitHub and runs the build of cntlm on this machine.
set -euo pipefail

CNTLM_VERSION=0.94.1
TUNNEL_VERSION=2.19.3
API=24
SDK="${ANDROID_HOME:-$HOME/Apps/android-sdk}"
NDK="${ANDROID_NDK_HOME:-$SDK/ndk/28.2.13676358}"
TOOLCHAIN="$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin"

HERE="$(cd "$(dirname "$0")" && pwd)"
APP="$HERE/../app"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$APP/libs"
curl -sSfL -o "$APP/libs/hev-socks5-tunnel.aar" \
  "https://github.com/heiher/hev-socks5-tunnel/releases/download/$TUNNEL_VERSION/hev-socks5-tunnel.aar"

curl -sSfL -o "$WORK/cntlm.tar.gz" \
  "https://github.com/versat/cntlm/archive/refs/tags/$CNTLM_VERSION.tar.gz"

for pair in arm64-v8a:aarch64-linux-android armeabi-v7a:armv7a-linux-androideabi x86_64:x86_64-linux-android; do
  abi="${pair%%:*}"
  triple="${pair##*:}"
  dir="$WORK/$abi"
  mkdir -p "$dir"
  tar xzf "$WORK/cntlm.tar.gz" -C "$dir" --strip-components=1
  cd "$dir"
  # The configure script runs its checks, so they describe this machine. Every
  # target ABI is little endian and Bionic has the same functions, except GSS.
  ./configure >/dev/null
  sed -i 's/config_gss 1/config_gss 0/' config/config.h
  echo "$TOOLCHAIN/${triple}${API}-clang" > configure-stamp
  # Bionic has pthreads in libc, there is no separate library to link.
  make -j"$(nproc)" LDFLAGS=-lm >/dev/null
  mkdir -p "$APP/src/main/jniLibs/$abi"
  "$TOOLCHAIN/llvm-strip" cntlm -o "$APP/src/main/jniLibs/$abi/libcntlm.so"
done

echo "Listo. Ya se puede compilar con: flutter build apk"
