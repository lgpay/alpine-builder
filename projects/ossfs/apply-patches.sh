#!/bin/sh
set -eu

SRC_ROOT="${1:-}"
if [ -z "$SRC_ROOT" ]; then
  echo "usage: $0 <ossfs-source-root>" >&2
  exit 1
fi

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$SRC_ROOT"

find_libfuse_tarball() {
  if [ -n "${LOCAL_LIBFUSE_TARBALL:-}" ] && [ -f "${LOCAL_LIBFUSE_TARBALL}" ]; then
    printf '%s\n' "$LOCAL_LIBFUSE_TARBALL"
    return 0
  fi

  WORKSPACE_ROOT="${GITHUB_WORKSPACE:-/workspace}"
  if [ -d "$WORKSPACE_ROOT" ]; then
    CANDIDATE=$(find "$WORKSPACE_ROOT" -type f -path "*/libfuse-*.tar.gz" | sort | tail -n 1 || true)
    if [ -n "$CANDIDATE" ] && [ -f "$CANDIDATE" ]; then
      printf '%s\n' "$CANDIDATE"
      return 0
    fi
  fi

  return 1
}

patch_libfuse_dependency() {
  [ -f dependencies/CMakeLists.txt ] || return 0

  LIBFUSE_HASH="04a5d2eca73e390f475ac785fe3d5145"
  LIBFUSE_TARBALL="$(find_libfuse_tarball || true)"
  if [ -n "$LIBFUSE_TARBALL" ]; then
    LIBFUSE_HASH=$(md5sum "$LIBFUSE_TARBALL" | awk '{print $1}')
    cp "$LIBFUSE_TARBALL" dependencies/pre-built/libfuse/libfuse-3.16.2-linux-x86_64.tar.gz
  fi

  sed -i "s/d84e371e77c82a2a18bec1b353633554/$LIBFUSE_HASH/" dependencies/CMakeLists.txt
  sed -i 's#libfuse3.so.3.16.2#libfuse3.so.3.18.2#' dependencies/CMakeLists.txt
}

ensure_musl_compat_source() {
  mkdir -p src/common
  cp "$SCRIPT_DIR/patches/musl_compat.cpp" src/common/musl_compat.cpp

  if [ -f CMakeLists.txt ] && ! grep -q 'src/common/musl_compat.cpp' CMakeLists.txt; then
    perl -0pi -e 's/add_executable\(ossfs2 \$\{ossfs2_srcs\}\)/add_executable(ossfs2 \$\{ossfs2_srcs\} src\/common\/musl_compat.cpp)/' CMakeLists.txt
  fi
}

patch_header_if_missing() {
  file="$1"
  needle="$2"
  anchor="$3"
  insert_text="$4"

  [ -f "$file" ] || return 0
  grep -q "$needle" "$file" && return 0

  awk -v anchor="$anchor" -v insert_text="$insert_text" '
    { print }
    $0 ~ anchor && !done {
      n = split(insert_text, lines, "\\n")
      for (i = 1; i <= n; ++i) print lines[i]
      done = 1
    }
  ' "$file" > "$file.tmp"
  mv "$file.tmp" "$file"
}

patch_source_files() {
  patch_header_if_missing src/common/utils.h '#include <time.h>' '#include <stdint.h>' '#include <time.h>'
  patch_header_if_missing src/fs/inode.h '#include <sys/types.h>' '#include <time.h>' '#include <sys/types.h>\n#include <sys/stat.h>'
  patch_header_if_missing src/fs/fs.cpp '#include <malloc.h>' '^#include ' '#include <malloc.h>'
  patch_header_if_missing src/main.cpp '#include <malloc.h>' '^#include ' '#include <malloc.h>'

  if [ -f src/fs/fs.cpp ] && ! grep -q 'static inline int malloc_trim(size_t)' src/fs/fs.cpp; then
    awk '
      { print }
      /^#include <fcntl.h>/ && !done {
        print "#ifndef __GLIBC__"
        print "static inline int malloc_trim(size_t) { return 0; }"
        print "#endif"
        done = 1
      }
    ' src/fs/fs.cpp > src/fs/fs.cpp.tmp
    mv src/fs/fs.cpp.tmp src/fs/fs.cpp
  fi

  if [ -f src/main.cpp ] && ! grep -q 'static inline int mallopt(int, int)' src/main.cpp; then
    awk '
      { print }
      /^#include <malloc.h>/ && !done {
        print "#ifndef __GLIBC__"
        print "#ifndef M_TRIM_THRESHOLD"
        print "#define M_TRIM_THRESHOLD (-1)"
        print "#endif"
        print "static inline int mallopt(int, int) { return 0; }"
        print "#endif"
        done = 1
      }
    ' src/main.cpp > src/main.cpp.tmp
    mv src/main.cpp.tmp src/main.cpp
  fi
}

patch_libfuse_dependency
ensure_musl_compat_source
patch_source_files
