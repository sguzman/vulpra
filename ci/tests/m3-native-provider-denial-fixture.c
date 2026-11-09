// Tiny synthetic Linux loader fixture, NOT a Vulpra browser runtime.
#include <dlfcn.h>
#include <stdio.h>
#include <string.h>
int main(int argc, char **argv) {
  if (argc != 3) { fputs("usage: target expected-denied|expected-allowed\n", stderr); return 2; }
  void *handle = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
  if (!strcmp(argv[2], "denied")) {
    if (handle) { dlclose(handle); fputs("FAIL: denied provider was loaded\n", stderr); return 1; }
    const char *why = dlerror();
    if (!why || !strstr(why, "__vulpra_ci_intentionally_absent_optional_provider__")) {
      fputs("FAIL: expected actual loader-error from forced unavailable provider\n", stderr); return 1;
    }
  } else if (!strcmp(argv[2], "allowed")) {
    if (!handle) { fprintf(stderr, "FAIL: allowed test provider: %s\n", dlerror()); return 1; }
    dlclose(handle);
  } else { fputs("FAIL: unknown expected outcome\n", stderr); return 2; }
  (void)argv;
  return 0;
}
