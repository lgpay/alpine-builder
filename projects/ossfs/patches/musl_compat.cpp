#ifndef __GLIBC__
#include <stddef.h>
#include <stdlib.h>

extern "C" int backtrace(void **, int) {
  return 0;
}

extern "C" char **backtrace_symbols(void *const *, int) {
  return static_cast<char **>(calloc(1, sizeof(char *)));
}
#endif
