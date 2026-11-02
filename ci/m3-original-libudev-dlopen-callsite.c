#define _GNU_SOURCE
#include <dlfcn.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

// Disposable CI-only diagnostic interposer; this modifies symbol binding.
// Compare to independently verified uninstrumented browser run 41371647131.
// Log only libudev.so.1 and return addresses originating in libxul.so.
// No browser data, credentials, PIDs, or raw paths are uploaded to artifacts.
typedef void *(*real_dlopen_t)(const char *, int);

__attribute__((noinline))
void *dlopen(const char *filename, int flags) {
  void *after_call = __builtin_extract_return_addr(__builtin_return_address(0));
  real_dlopen_t real = (real_dlopen_t)dlsym(RTLD_NEXT, "dlopen");
  if (!real) _exit(98);
  void *result = real(filename, flags);
  if (filename && strcmp(filename, "libudev.so.1") == 0) {
    Dl_info caller = {0};
    if (dladdr(after_call, &caller) && caller.dli_fname && caller.dli_fbase) {
      const char *base = strrchr(caller.dli_fname, '/');
      base = base ? base + 1 : caller.dli_fname;
      if (strcmp(base, "libxul.so") == 0) {
        const char *out = getenv("VULPRA_M3_LIBUDEV_DLOPEN_TRACE");
        if (out && strcmp(out, "/tmp/vulpra-m3-libudev-dlopen.trace") == 0) {
          uintptr_t pc = (uintptr_t)after_call - (uintptr_t)caller.dli_fbase;
          char line[160];
          int len = snprintf(line, sizeof(line), "%ld\t0x%lx\t0x%x\t%s\n",
                             (long)getpid(), (unsigned long)pc,
                             (unsigned int)flags, result ? "hit" : "miss");
          if (len > 0 && len < (int)sizeof(line)) {
            int fd = open(out, O_WRONLY | O_CREAT | O_APPEND | O_CLOEXEC | O_NOFOLLOW, 0600);
            if (fd >= 0) {
              ssize_t wrote = write(fd, line, (size_t)len);
              if (wrote != len) { /* The downstream fail-closed check rejects an incomplete trace. */ }
              (void)close(fd);
            }
          }
        }
      }
    }
  }
  return result;
}
