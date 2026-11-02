/* CI-only optional diagnostic: attribute dlopen to original ONNX module
 * from the immediate return PC. Compiled with -fno-omit-frame-pointer.
 * LD_PRELOAD alters native symbol binding; never claim uninstrumented proof.
 * Do not export paths, PIDs, library arguments, stack addresses, or names.
 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdatomic.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static _Atomic unsigned long calls_total;
static _Atomic unsigned long calls_onnx;
static _Atomic unsigned long calls_onnx_ok;
static _Atomic unsigned long calls_onnx_failed;
static _Atomic unsigned long calls_other;
static void *(*next_dlopen)(const char *, int);

static int onnx_origin(void *return_address) {
  Dl_info info;
  if (!return_address || dladdr(return_address, &info) == 0 ||
      info.dli_fname == NULL) {
    return 0;
  }
  const char *slash = strrchr(info.dli_fname, '/');
  const char *base = slash ? slash + 1 : info.dli_fname;
  return strcmp(base, "libonnxruntime.so") == 0;
}

__attribute__((noinline, visibility("default")))
void *dlopen(const char *name, int flags) {
  void *return_address = __builtin_extract_return_addr(__builtin_return_address(0));
  int from_onnx = onnx_origin(return_address);
  if (!next_dlopen) {
    void *sym = dlsym(RTLD_NEXT, "dlopen");
    if (!sym) {
      _Exit(126);
    }
    /* Linux/glibc function-pointer representation is pointer sized. */
    memcpy(&next_dlopen, &sym, sizeof next_dlopen);
  }
  void *result = next_dlopen(name, flags);
  atomic_fetch_add(&calls_total, 1);
  if (from_onnx) {
    atomic_fetch_add(&calls_onnx, 1);
    if (result) {
      atomic_fetch_add(&calls_onnx_ok, 1);
    } else {
      atomic_fetch_add(&calls_onnx_failed, 1);
    }
  } else {
    atomic_fetch_add(&calls_other, 1);
  }
  return result;
}

__attribute__((destructor))
static void save_bounded_report(void) {
  const char *path = getenv("M3_ONNX_INNER_DLOPEN_REPORT");
  if (!path || path[0] != '/' || strstr(path, "..") || strlen(path) > 4096) {
    return;
  }
  FILE *f = fopen(path, "wx");
  if (!f) return;
  unsigned long total = atomic_load(&calls_total);
  unsigned long onnx = atomic_load(&calls_onnx);
  unsigned long ok = atomic_load(&calls_onnx_ok);
  unsigned long failed = atomic_load(&calls_onnx_failed);
  unsigned long other = atomic_load(&calls_other);
  fprintf(f,
          "{\n\"schema_version\":1,"
          "\n\"diagnostic_interposition_used\":true,"
          "\n\"target_origin_basename\":\"libonnxruntime.so\","
          "\n\"all_interposed_dlopen_calls\":%lu,"
          "\n\"onnx_origin_dlopen_calls\":%lu,"
          "\n\"onnx_origin_successful_dlopen_calls\":%lu,"
          "\n\"onnx_origin_failed_dlopen_calls\":%lu,"
          "\n\"other_origin_dlopen_calls\":%lu,"
          "\n\"raw_caller_addresses_or_library_names_retained\":false,"
          "\n\"complete_native_loader_graph_proven\":false}\n",
          total, onnx, ok, failed, other);
  fclose(f);
}
