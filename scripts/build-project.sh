#!/bin/sh
set -eu

PROJECT_NAME="${PROJECT_NAME:?PROJECT_NAME is required}"
SOURCE_REPO="${SOURCE_REPO:?SOURCE_REPO is required}"
SOURCE_REF="${SOURCE_REF:-master}"
BUILD_SYSTEM="${BUILD_SYSTEM:-meson}"
INSTALL_PREFIX="${INSTALL_PREFIX:-/usr}"
CONFIGURE_ARGS="${CONFIGURE_ARGS:-}"
BUILD_ARGS="${BUILD_ARGS:-}"
INSTALL_ARGS="${INSTALL_ARGS:-}"
PACKAGE_DIRS="${PACKAGE_DIRS:-bin sbin lib lib64 include share}"

SRC_DIR=/tmp/src
PKGROOT=/tmp/pkgroot
INSTALL_ROOT="$PKGROOT$INSTALL_PREFIX"

rm -rf "$SRC_DIR" "$PKGROOT"
mkdir -p "$SRC_DIR" "$PKGROOT"

git clone "$SOURCE_REPO" "$SRC_DIR"
cd "$SRC_DIR"
git checkout "$SOURCE_REF"

echo "GIT_DESCRIBE=$(git describe --tags --always --dirty 2>/dev/null || git rev-parse --short HEAD)" >> "$GITHUB_ENV"
echo "GIT_SHA=$(git rev-parse --short HEAD)" >> "$GITHUB_ENV"

echo "Building $PROJECT_NAME from $SOURCE_REPO @ $SOURCE_REF using $BUILD_SYSTEM"

case "$BUILD_SYSTEM" in
  meson)
    sh -lc "meson setup build --buildtype=release --prefix=$INSTALL_PREFIX $CONFIGURE_ARGS"
    sh -lc "meson compile -C build $BUILD_ARGS"
    DESTDIR="$PKGROOT" sh -lc "meson install -C build $INSTALL_ARGS"
    ;;
  cmake)
    sh -lc "cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$INSTALL_PREFIX $CONFIGURE_ARGS"
    sh -lc "cmake --build build $BUILD_ARGS"
    DESTDIR="$PKGROOT" sh -lc "cmake --install build $INSTALL_ARGS"
    ;;
  autotools)
    sh -lc "./autogen.sh || true"
    sh -lc "./configure --prefix=$INSTALL_PREFIX $CONFIGURE_ARGS"
    sh -lc "make $BUILD_ARGS"
    DESTDIR="$PKGROOT" sh -lc "make install $INSTALL_ARGS"
    ;;
  make)
    sh -lc "make $BUILD_ARGS"
    DESTDIR="$PKGROOT" PREFIX="$INSTALL_PREFIX" sh -lc "make install $INSTALL_ARGS"
    ;;
  *)
    echo "Unsupported BUILD_SYSTEM: $BUILD_SYSTEM" >&2
    exit 1
    ;;
esac

mkdir -p /tmp/out
"$GITHUB_WORKSPACE/scripts/package.sh" "$INSTALL_ROOT" /tmp/out "${GIT_DESCRIBE:-${GIT_SHA:-unknown}}" "${ALPINE_VERSION:-unknown}" "${TARGET_ARCH:-unknown}" "$PROJECT_NAME" "$PACKAGE_DIRS"
