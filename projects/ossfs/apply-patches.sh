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

  # ossfs dependencies/CMakeLists.txt ships per-arch prebuilt libfuse tarballs:
  #   x86_64  -> libfuse-3.16.2-linux-x86_64.tar.gz  (upstream MD5 d84e371e77c82a2a18bec1b353633554)
  #   aarch64 -> libfuse-3.16.2-linux-aarch64.tar.gz (upstream MD5 e3cf7d710562cb82c0e88fbd49cb4711)
  # Replace the matching arch's tarball with the freshly-built libfuse and
  # rewrite its URL_HASH, so the ExternalProject download/verify step succeeds
  # for both architectures. Previously only the x86_64 path/hash was touched,
  # which left aarch64 pointing at the stale upstream 3.16.2 tarball while the
  # soname lookup was rewritten to 3.18.2 -> "No rule to make target" failure.
  case "${TARGET_ARCH:-$(uname -m)}" in
    x86_64|amd64)  ARCH_TAG=x86_64;  UPSTREAM_HASH=d84e371e77c82a2a18bec1b353633554 ;;
    aarch64|arm64) ARCH_TAG=aarch64; UPSTREAM_HASH=e3cf7d710562cb82c0e88fbd49cb4711 ;;
    *) echo "Unsupported arch for libfuse patching: ${TARGET_ARCH:-unknown}" >&2; return 1 ;;
  esac

  LIBFUSE_TARBALL="$(find_libfuse_tarball || true)"
  if [ -n "$LIBFUSE_TARBALL" ]; then
    LIBFUSE_HASH=$(md5sum "$LIBFUSE_TARBALL" | awk '{print $1}')
    cp "$LIBFUSE_TARBALL" "dependencies/pre-built/libfuse/libfuse-3.16.2-linux-${ARCH_TAG}.tar.gz"
    sed -i "s/$UPSTREAM_HASH/$LIBFUSE_HASH/" dependencies/CMakeLists.txt
    # upstream references libfuse3.so.3.16.2; the freshly built libfuse ships a
    # newer soname (e.g. 3.18.2), so rewrite the lookup name to match.
    sed -i 's#libfuse3.so.3.16.2#libfuse3.so.3.18.2#' dependencies/CMakeLists.txt
  fi
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
  patch_header_if_missing src/fs/file_writer.cpp '#include <sys/stat.h>' '^#include ' '#include <sys/stat.h>'
  patch_header_if_missing src/fs/file_writer.cpp '#define S_BLKSIZE' '#include <sys/stat.h>' '#ifndef S_BLKSIZE\n#define S_BLKSIZE 512\n#endif'
  patch_header_if_missing src/fs/fs.cpp '#include <malloc.h>' '^#include ' '#include <malloc.h>'
  patch_header_if_missing src/fs/fs.cpp '#include <sys/file.h>' '^#include ' '#include <sys/file.h>'
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

patch_cpp_redirect_warning() {
  # musl libc emits a #warning redirecting <sys/poll.h> -> <poll.h>. With
  # -Werror (set by ossfs CMakeLists.txt) this harmless redirect becomes a
  # fatal -Werror=cpp error and aborts the build. Exempt just this warning so
  # real warnings still fail the build, mirroring the existing
  # -Wno-error=unused-result pattern.
  [ -f CMakeLists.txt ] || return 0
  grep -q -- '-Wno-error=cpp' CMakeLists.txt && return 0
  sed -i 's/\(-Wno-error=unused-result\)/\1 -Wno-error=cpp/' CMakeLists.txt
}

patch_libfuse_dependency
ensure_musl_compat_source
patch_source_files
patch_cpp_redirect_warning
