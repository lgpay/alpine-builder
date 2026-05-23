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
SOURCE_SUBDIR="${SOURCE_SUBDIR:-.}"
PRE_BUILD_HOOK="${PRE_BUILD_HOOK:-}"
POST_CLONE_HOOK="${POST_CLONE_HOOK:-}"

SRC_DIR=/tmp/src
PKGROOT=/tmp/pkgroot
INSTALL_ROOT="$PKGROOT$INSTALL_PREFIX"

rm -rf "$SRC_DIR" "$PKGROOT"
mkdir -p "$SRC_DIR" "$PKGROOT"

git clone "$SOURCE_REPO" "$SRC_DIR"
cd "$SRC_DIR"
git checkout "$SOURCE_REF"

if [ -n "$POST_CLONE_HOOK" ]; then
  sh -lc "$POST_CLONE_HOOK"
fi

cd "$SRC_DIR/$SOURCE_SUBDIR"

GIT_DESCRIBE_VALUE="$(git describe --tags --always --dirty 2>/dev/null || git rev-parse --short HEAD)"
GIT_SHA_VALUE="$(git rev-parse --short HEAD)"
PACKAGE_VERSION_VALUE="${SOURCE_REF:-$GIT_DESCRIBE_VALUE}"
export GIT_DESCRIBE="$GIT_DESCRIBE_VALUE"
export GIT_SHA="$GIT_SHA_VALUE"
export PACKAGE_VERSION="$PACKAGE_VERSION_VALUE"

if [ -n "${GITHUB_ENV:-}" ]; then
  echo "GIT_DESCRIBE=$GIT_DESCRIBE_VALUE" >> "$GITHUB_ENV"
  echo "GIT_SHA=$GIT_SHA_VALUE" >> "$GITHUB_ENV"
  echo "PACKAGE_VERSION=$PACKAGE_VERSION_VALUE" >> "$GITHUB_ENV"
fi

echo "Building $PROJECT_NAME from $SOURCE_REPO @ $SOURCE_REF using $BUILD_SYSTEM"

if [ -n "$PRE_BUILD_HOOK" ]; then
  sh -lc "$PRE_BUILD_HOOK"
fi

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
"$GITHUB_WORKSPACE/scripts/package.sh" "$INSTALL_ROOT" /tmp/out "${PACKAGE_VERSION:-${GIT_DESCRIBE:-${GIT_SHA:-unknown}}}" "${ALPINE_VERSION:-unknown}" "${TARGET_ARCH:-unknown}" "$PROJECT_NAME" "$PACKAGE_DIRS"
