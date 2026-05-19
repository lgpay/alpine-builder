#!/bin/sh
set -eu

PREFIX_DIR="${1:-}"
OUT_DIR="${2:-}"
VERSION="${3:-unknown}"
ALPINE_VERSION="${4:-unknown}"
ARCH="${5:-unknown}"
PROJECT_NAME="${6:-package}"
PACKAGE_DIRS_RAW="${7:-bin sbin lib lib64 include share}"

if [ -z "$PREFIX_DIR" ] || [ -z "$OUT_DIR" ]; then
  echo "usage: $0 <prefix_dir> <out_dir> [version] [alpine_version] [arch] [project_name] [package_dirs]" >&2
  exit 1
fi

PKG_ROOT="$OUT_DIR/${PROJECT_NAME}-alpine-${VERSION}-apk${ALPINE_VERSION}-${ARCH}"
mkdir -p "$PKG_ROOT"

for dir in $PACKAGE_DIRS_RAW; do
  if [ -d "$PREFIX_DIR/$dir" ]; then
    cp -a "$PREFIX_DIR/$dir" "$PKG_ROOT/"
  fi
done

find "$PKG_ROOT" -type f | sort > "$PKG_ROOT/CONTENTS.txt"

cat > "$PKG_ROOT/BUILD-INFO.txt" <<EOF
project=$PROJECT_NAME
version=$VERSION
alpine_version=$ALPINE_VERSION
arch=$ARCH
built_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF

TAR_PATH="$OUT_DIR/$(basename "$PKG_ROOT").tar.gz"
tar -C "$OUT_DIR" -czf "$TAR_PATH" "$(basename "$PKG_ROOT")"

SHA_PATH="$TAR_PATH.sha256"
(
  cd "$OUT_DIR"
  sha256sum "$(basename "$TAR_PATH")"
) > "$SHA_PATH"

echo "Created package: $TAR_PATH"
echo "Created checksum: $SHA_PATH"
