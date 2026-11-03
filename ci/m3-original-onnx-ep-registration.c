// Bounded original ONNX v30 EP registration/teardown and optional CPU fallback test.
// The CI-owned external EP implements no kernels and never executes model nodes.
// A separate, source-pinned manual CI workflow supplies the original ELF.
#include "onnxruntime_c_api.h"
#include <dlfcn.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Session implementation is kept in a separate, focused C translation unit.
int m3_probe_cpu_fallback_session(const OrtApi *api, OrtEnv *env,
                                  const OrtEpDevice *device);
int m3_probe_external_ep_compute_session(const OrtApi *api, OrtEnv *env,
                                         const OrtEpDevice *device);

#if ORT_API_VERSION != 30
#error "This probe requires exactly ORT C API v30"
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
  if (base != NULL) {
    fprintf(stderr, "M3_EP_ORIGINAL_VERSION=%.80s v30=%d v31=%d\n",
            base->GetVersionString(), base->GetApi(30) != NULL,
            base->GetApi(31) != NULL);
    fflush(stderr);
  }
  const OrtApi *api = base != NULL ? base->GetApi(30) : NULL;
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
  const char *device_mode = getenv("VULPRA_CI_ONNX_EP_DEVICE_PROBE");
  const char *session_mode = getenv("VULPRA_CI_ONNX_EP_CPU_FALLBACK");
  int run_cpu_fallback = session_mode != NULL && strcmp(session_mode, "1") == 0;
  const char *compute_mode = getenv("VULPRA_CI_ONNX_EP_NATIVE_COMPUTE");
  int run_native_compute = compute_mode != NULL && strcmp(compute_mode, "1") == 0;
  if (run_cpu_fallback || run_native_compute ||
      (device_mode != NULL && strcmp(device_mode, "1") == 0)) {
    const OrtEpDevice *const *ep_devices = NULL;
    size_t ep_count = 0;
    int query_ok = check_status(api,
        api->GetEpDevices(env, &ep_devices, &ep_count), "enumerate_ep_devices");
    size_t matching_cpu_devices = 0;
    const OrtEpDevice *matched_device = NULL;
    if (query_ok && ep_count <= 64 && (ep_count == 0 || ep_devices != NULL)) {
      for (size_t i = 0; i < ep_count; ++i) {
        const OrtEpDevice *device = ep_devices[i];
        if (device == NULL) {
          query_ok = 0;
          break;
        }
        const char *name = api->EpDevice_EpName(device);
        if (name != NULL && strcmp(name, "VulpraCIProbeEP") == 0) {
          const OrtHardwareDevice *hardware = api->EpDevice_Device(device);
          if (hardware == NULL ||
              api->HardwareDevice_Type(hardware) != OrtHardwareDeviceType_CPU) {
            query_ok = 0;
            break;
          }
          ++matching_cpu_devices;
          matched_device = device;
        }
      }
    } else {
      query_ok = 0;
    }
    if (!query_ok || matching_cpu_devices != 1) {
      fprintf(stderr, "M3_EP_ERROR_STAGE=cpu_ep_device_enumeration matches=%zu\n",
              matching_cpu_devices);
      OrtStatus *cleanup = api->UnregisterExecutionProviderLibrary(
          env, "vulpra-ci-fixture");
      if (cleanup != NULL) api->ReleaseStatus(cleanup);
      api->ReleaseEnv(env);
      dlclose(handle);
      return 8;
    }
    puts("M3_EP_STAGE=cpu_ep_device_enumerated"); fflush(stdout);
    if (run_cpu_fallback || run_native_compute) {
      int result = run_native_compute
                       ? m3_probe_external_ep_compute_session(api, env, matched_device)
                       : m3_probe_cpu_fallback_session(api, env, matched_device);
      if (result != 0) {
        fputs("M3_EP_ERROR_STAGE=cpu_fallback_session\n", stderr);
        OrtStatus *cleanup = api->UnregisterExecutionProviderLibrary(
            env, "vulpra-ci-fixture");
        if (cleanup != NULL) api->ReleaseStatus(cleanup);
        api->ReleaseEnv(env);
        dlclose(handle);
        return 9;
      }
      puts(run_native_compute ? "M3_EP_STAGE=external_ep_model_pass"
                              : "M3_EP_STAGE=cpu_fallback_model_pass");
      fflush(stdout);
    }
  }
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
