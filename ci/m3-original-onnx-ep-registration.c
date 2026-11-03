// Bounded original ONNX v22 EP registration/teardown test; never runs an EP.
// A separate, source-pinned manual CI workflow supplies the original ELF.
#include "onnxruntime_c_api.h"
#include <dlfcn.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>

#if ORT_API_VERSION != 22
#error "This probe requires exactly ORT C API v22"
#endif
_Static_assert(offsetof(OrtApi, UnregisterExecutionProviderLibrary) ==
                   offsetof(OrtApi, RegisterExecutionProviderLibrary) + sizeof(void *),
               "EP registration ABI functions must occupy consecutive slots");

static int check_status(const OrtApi *api, OrtStatus *status,
                        const char *stage) {
  if (status == NULL) {
    return 1;
  }
  fprintf(stderr, "M3_EP_ERROR_STAGE=%s code=%d detail=%.240s\n", stage,
          (int)api->GetErrorCode(status), api->GetErrorMessage(status));
  api->ReleaseStatus(status);
  return 0;
}

int main(int argc, char **argv) {
  if (argc != 3) {
    fputs("usage: probe /absolute/libonnxruntime.so /absolute/libfixture.so\n",
          stderr);
    return 2;
  }
  if (argv[1][0] != '/' || argv[2][0] != '/') {
    fputs("both library paths must be absolute\n", stderr);
    return 2;
  }
  void *handle = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
  if (handle == NULL) {
    fputs("M3_EP_ERROR_STAGE=load_original_elf\n", stderr);
    return 3;
  }
  const OrtApiBase *(*get_api_base)(void) =
      (const OrtApiBase *(*)(void))dlsym(handle, "OrtGetApiBase");
  if (get_api_base == NULL) {
    fputs("M3_EP_ERROR_STAGE=lookup_api_base\n", stderr);
    dlclose(handle);
    return 3;
  }
  const OrtApiBase *base = get_api_base();
  const OrtApi *api = base != NULL ? base->GetApi(22) : NULL;
  if (api == NULL || api->RegisterExecutionProviderLibrary == NULL ||
      api->UnregisterExecutionProviderLibrary == NULL) {
    fputs("M3_EP_ERROR_STAGE=api22_unavailable\n", stderr);
    dlclose(handle);
    return 4;
  }
  OrtEnv *env = NULL;
  if (!check_status(api, api->CreateEnv(ORT_LOGGING_LEVEL_ERROR,
                                        "VulpraCIProbeEP", &env), "create_env") ||
      env == NULL) {
    dlclose(handle);
    return 5;
  }
  puts("M3_EP_STAGE=register"); fflush(stdout);
  int registered = check_status(
      api, api->RegisterExecutionProviderLibrary(
               env, "vulpra-ci-fixture", argv[2]), "register");
  if (!registered) {
    api->ReleaseEnv(env);
    dlclose(handle);
    return 6;
  }
  puts("M3_EP_STAGE=registration_succeeded"); fflush(stdout);
  puts("M3_EP_STAGE=unregister"); fflush(stdout);
  int unregistered = check_status(
      api, api->UnregisterExecutionProviderLibrary(
               env, "vulpra-ci-fixture"), "unregister");
  if (unregistered) {
    puts("M3_EP_STAGE=unregistration_succeeded"); fflush(stdout);
  }
  api->ReleaseEnv(env);
  if (dlclose(handle) != 0 || !unregistered) {
    return 7;
  }
  puts("PASS: original ONNX registered and unregistered CI-only factory");
  return 0;
}
