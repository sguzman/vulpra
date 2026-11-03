// CI-only ONNX Runtime 1.22 EP factory. No devices, kernels, or production EP.
// Compile against the SHA-pinned v1.22.0 onnxruntime_c_api.h in the workflow.
#include "onnxruntime_c_api.h"
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#if ORT_API_VERSION != 22
#error "This fixture intentionally targets the pinned ORT C API v22 only"
#endif

static const OrtApi *runtime_api;
static const char provider_name[] = "VulpraCIProbeEP";
static const char vendor_name[] = "Vulpra CI fixture";

static const char *ORT_API_CALL get_name(const OrtEpFactory *factory) {
  (void)factory;
  return provider_name;
}

static const char *ORT_API_CALL get_vendor(const OrtEpFactory *factory) {
  (void)factory;
  return vendor_name;
}

// This test plugin claims NO real hardware or supported OrtEpDevice.
static OrtStatus *ORT_API_CALL get_supported_devices(
    OrtEpFactory *factory, const OrtHardwareDevice *const *devices,
    size_t device_count, OrtEpDevice **ep_devices, size_t max_ep_devices,
    size_t *num_ep_devices) {
  (void)factory;
  (void)devices;
  (void)device_count;
  (void)ep_devices;
  (void)max_ep_devices;
  if (num_ep_devices == NULL) {
    return runtime_api != NULL
               ? runtime_api->CreateStatus(ORT_INVALID_ARGUMENT, "missing count")
               : NULL;
  }
  *num_ep_devices = 0;
  return NULL;
}

// Required API callback, deliberately unreachable without advertised devices.
static OrtStatus *ORT_API_CALL create_ep(
    OrtEpFactory *factory, const OrtHardwareDevice *const *devices,
    const OrtKeyValuePairs *const *metadata, size_t device_count,
    const OrtSessionOptions *session_options, const OrtLogger *logger,
    OrtEp **ep) {
  (void)factory;
  (void)devices;
  (void)metadata;
  (void)device_count;
  (void)session_options;
  (void)logger;
  if (ep != NULL) {
    *ep = NULL;
  }
  return runtime_api != NULL
             ? runtime_api->CreateStatus(ORT_NOT_IMPLEMENTED,
                                         "CI fixture does not execute models")
             : NULL;
}

static void ORT_API_CALL release_ep(OrtEpFactory *factory, OrtEp *ep) {
  (void)factory;
  (void)ep;  // No EP can be created by this non-executing fixture.
}

static OrtEpFactory *make_factory(void) {
  OrtEpFactory *factory = (OrtEpFactory *)calloc(1, sizeof(*factory));
  if (factory == NULL) {
    return NULL;
  }
  factory->ort_version_supported = ORT_API_VERSION;
  factory->GetName = get_name;
  factory->GetVendor = get_vendor;
  factory->GetSupportedDevices = get_supported_devices;
  factory->CreateEp = create_ep;
  factory->ReleaseEp = release_ep;
  return factory;
}

#if defined(__GNUC__)
#define M3_EXPORT __attribute__((visibility("default")))
#else
#define M3_EXPORT
#endif

M3_EXPORT OrtStatus *CreateEpFactories(
    const char *registered_name, const OrtApiBase *api_base,
    OrtEpFactory **factories, size_t max_factories, size_t *num_factories) {
  fputs("M3_EP_CALLBACK=entered_factory_init\n", stderr);
  fflush(stderr);\n  const OrtApi *fallback = api_base != NULL ? api_base->GetApi(1) : NULL;
  if (num_factories != NULL) {
    *num_factories = 0;
  }
  if (registered_name == NULL || api_base == NULL || factories == NULL ||
      num_factories == NULL || max_factories == 0) {
    return fallback != NULL
               ? fallback->CreateStatus(ORT_INVALID_ARGUMENT,
                                        "invalid fixture factory arguments")
               : NULL;
  }
  fputs("M3_EP_CALLBACK=before_api22\n", stderr);
  fflush(stderr);\n  const OrtApi *api22 = api_base->GetApi(ORT_API_VERSION);
  if (api22 == NULL) {
    return fallback != NULL
               ? fallback->CreateStatus(ORT_NOT_IMPLEMENTED,
                                        "ORT API v22 required")
               : NULL;
  }
  OrtEpFactory *factory = make_factory();
  if (factory == NULL) {
    return api22->CreateStatus(ORT_FAIL, "CI factory allocation failed");
  }
  runtime_api = api22;
  factories[0] = factory;
  *num_factories = 1;  // Unlike the retired zero-factory crash experiment.
  fputs("M3_EP_CALLBACK=factory_created\n", stderr);
  fflush(stderr);
  return NULL;
}

M3_EXPORT OrtStatus *ReleaseEpFactory(OrtEpFactory *factory) {
  free(factory);
  fputs("M3_EP_CALLBACK=factory_released\n", stderr);
  fflush(stderr);
  return NULL;
}

#ifdef M3_EP_FIXTURE_SELFTEST
int main(void) {
  OrtEpFactory *factory = make_factory();
  if (factory == NULL || factory->ort_version_supported != 22 ||
      factory->GetName == NULL || factory->GetVendor == NULL ||
      factory->GetSupportedDevices == NULL || factory->CreateEp == NULL ||
      factory->ReleaseEp == NULL ||
      strcmp(factory->GetName(factory), provider_name) != 0 ||
      strcmp(factory->GetVendor(factory), vendor_name) != 0) {
    return 1;
  }
  size_t count = SIZE_MAX;
  if (factory->GetSupportedDevices(factory, NULL, 0, NULL, 0, &count) != NULL ||
      count != 0) {
    return 2;
  }
  if (ReleaseEpFactory(factory) != NULL) {
    return 3;
  }
  puts("PASS: pinned-header fixture callbacks, one factory, no devices, teardown");
  return 0;
}
#endif
