#ifndef __GLIBC__
#include <stddef.h>
#include <stdlib.h>
#include <pthread.h>
#include <time.h>

extern "C" int backtrace(void **, int) {
  return 0;
}

extern "C" char **backtrace_symbols(void *const *, int) {
  return static_cast<char **>(calloc(1, sizeof(char *)));
}

// The PhotonLibOS aarch64 prebuilt was built against glibc and references
// pthread_cond_clockwait (glibc 2.30+); musl does not export it, which left
// the ossfs2 link undefined on aarch64. Provide a weak fallback that
// delegates to pthread_cond_timedwait so the symbol resolves on musl without
// clashing if a future musl ever exports it natively.
extern "C" __attribute__((weak))
int pthread_cond_clockwait(pthread_cond_t *cond, pthread_mutex_t *mutex,
                           clockid_t /*clockid*/, const struct timespec *abstime) {
  return pthread_cond_timedwait(cond, mutex, abstime);
}
#endif
