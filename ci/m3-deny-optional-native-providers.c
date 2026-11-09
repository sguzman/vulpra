// Linux-only conditional provider-denial interposer for a disposable packaged
// Vulpra runtime smoke. No system library installation/removal, no browser
// source modification, no user profile. Never treat absence of an observed
// attempted load as proof of a tested missing-provider fallback.
#define _GNU_SOURCE
#include <dlfcn.h>
#include <fcntl.h>
#include <limits.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <unistd.h>

static _Thread_local int reentry;

static bool browser_process(void) {
  const char *fixture = getenv("VULPRA_M3_DENY_FIXTURE_EXE");
  char exe[PATH_MAX];
  ssize_t n = readlink("/proc/self/exe", exe, sizeof(exe) - 1);
  if (n <= 0 || (size_t)n >= sizeof(exe) - 1) return false;
  exe[n] = '\0';
  const char *name = strrchr(exe, '/');
  name = name ? name + 1 : exe;
  if (!strcmp(name, "vulpra") || !strcmp(name, "firefox")) return true;
  // Only named, explicitly opted-in synthetic fixture executables.
  return fixture && !strcmp(name, fixture);
}

// An absence of blocked calls is not meaningful unless the real browser
// process actually loaded this shim. Emit a narrow attachment witness.
__attribute__((constructor)) static void note_real_process_attachment(void) {
  if (!browser_process()) return;
  const char *log = getenv("VULPRA_M3_DENY_LOG");
  if (!log || log[0] != '/' || strlen(log) >= PATH_MAX) return;
  int fd = open(log, O_APPEND | O_WRONLY | O_CLOEXEC | O_NOFOLLOW);
  if (fd < 0) return;
  char line[128];
  int n = snprintf(line, sizeof(line), "ATTACHED browser-process %ld\n",
                   (long)getpid());
  if (n > 0 && n < (int)sizeof(line)) {
    ssize_t written = write(fd, line, (size_t)n);
    (void)written; // Attachment is subsequently required by the CI report.
  }
  (void)close(fd);
}

static bool group_matches(const char *group, const char *name) {
  if (!group || !name || !*name) return false;
  const char *base = strrchr(name, '/');
  base = base ? base + 1 : name;
  bool gbm = !strcmp(base, "libgbm.so.1") || !strcmp(base, "libdrm.so.2");
  bool va = !strcmp(base, "libva.so.2") || !strcmp(base, "libva-drm.so.2");
  bool ff = !strncmp(base, "libavcodec.so.", 14) ||
            !strncmp(base, "libavcodec-ffmpeg.so.", 21);
  if (!strcmp(group, "gbm")) return gbm;
  if (!strcmp(group, "vaapi")) return va;
  if (!strcmp(group, "ffmpeg")) return ff;
  return false;
}

static bool deny(const char *name, const char *api) {
  if (reentry || !name) return false;
  ++reentry;
  const char *group = getenv("VULPRA_M3_DENY_GROUP");
  bool hit = browser_process() && group_matches(group, name);
  if (hit) {
    const char *log = getenv("VULPRA_M3_DENY_LOG");
    if (log && log[0] == '/' && strlen(log) < PATH_MAX) {
      int fd = open(log, O_APPEND | O_WRONLY | O_CLOEXEC | O_NOFOLLOW);
      if (fd >= 0) {
        // Only fixed allowlisted library names reach the log.
        char line[256];
        int n = snprintf(line, sizeof(line), "DENIED %s %s %ld\n",
                         api, name, (long)getpid());
        if (n > 0 && n < (int)sizeof(line)) {
          ssize_t written = write(fd, line, (size_t)n);
          if (written != (ssize_t)n) {
            (void)close(fd);
            --reentry;
            return false; // No silent denial when evidence logging failed.
          }
        }
        (void)close(fd);
      }
    }
  }
  --reentry;
  return hit;
}

void *dlopen(const char *filename, int flags) {
  static void *(*next)(const char *, int);
  if (!next) next = (void *(*)(const char *, int))dlsym(RTLD_NEXT, "dlopen");
  if (!next) return NULL;
  if (deny(filename, "dlopen"))
    return next("__vulpra_ci_intentionally_absent_optional_provider__.so", flags);
  return next(filename, flags);
}

void *dlmopen(Lmid_t nsid, const char *filename, int flags) {
  static void *(*next)(Lmid_t, const char *, int);
  if (!next) next = (void *(*)(Lmid_t, const char *, int))dlsym(RTLD_NEXT, "dlmopen");
  if (!next) return NULL;
  if (deny(filename, "dlmopen"))
    return next(nsid, "__vulpra_ci_intentionally_absent_optional_provider__.so", flags);
  return next(nsid, filename, flags);
}
