#define _GNU_SOURCE
#include <dlfcn.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

// CI-only interposer: narrowly witness native libxul.so -> libpulse.so.0 dlopen.
// Original normal WebAudio playback was separately witnessed without LD_PRELOAD
// in CI 41487961096. Interposing changes dynamic symbol resolution; this
// cannot prove an uninstrumented loader call stack or exact Rust FFI instructions.
// Only sanitized booleans/counts are uploaded; no raw trace/PIDs/paths.
typedef void *(*real_dlopen_t)(const char *, int);
__attribute__((noinline))
void *dlopen(const char *filename, int flags) {
  void *retpc = __builtin_extract_return_addr(__builtin_return_address(0));
  real_dlopen_t real = (real_dlopen_t)dlsym(RTLD_NEXT, "dlopen");
  if (!real) _exit(98);
  void *result = real(filename, flags);
  if (filename && strcmp(filename, "libpulse.so.0") == 0) {
    Dl_info info = {0};
    if (dladdr(retpc, &info) && info.dli_fname && info.dli_fbase) {
      const char *base = strrchr(info.dli_fname, '/');
      base = base ? base + 1 : info.dli_fname;
      if (strcmp(base, "libxul.so") == 0) {
        const char *path = getenv("VULPRA_M3_LIBPULSE_DLOPEN_TRACE");
        if (path && strcmp(path, "/tmp/vulpra-m3-libpulse-dlopen.trace") == 0) {
          uintptr_t pc = (uintptr_t)retpc - (uintptr_t)info.dli_fbase;
          char record[160];
          int n = snprintf(record, sizeof(record), "%ld\t0x%lx\t0x%x\t%s\n",
                           (long)getpid(), (unsigned long)pc, (unsigned int)flags,
                           result ? "hit" : "miss");
          if (n > 0 && n < (int)sizeof(record)) {
            int fd = open(path, O_WRONLY | O_CREAT | O_APPEND |
                                O_CLOEXEC | O_NOFOLLOW, 0600);
            if (fd >= 0) {
              ssize_t actual = write(fd, record, (size_t)n);
              // A partial write is rejected by the downstream parser.
              (void)actual;
              (void)close(fd);
            }
          }
        }
      }
    }
  }
  return result;
}
