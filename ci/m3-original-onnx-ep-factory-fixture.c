// CI-only ONNX Runtime 1.30 EP factory. All device/session/compute modes opt-in;
// one separate scalar CPU Mul test implementation, no accelerator or production EP.
// Compile against the SHA-pinned v1.30.0 onnxruntime_c_api.h and ep_c_api.h in the workflow.
#include "onnxruntime_c_api.h"
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#if ORT_API_VERSION != 30
#error "This fixture intentionally targets the pinned ORT C API v30 only"
#endif

static const OrtApi *runtime_api;
static const OrtEpApi *runtime_ep_api;
static int enumerate_ci_cpu_device;
static int enable_ci_cpu_fallback_session;
static int enable_ci_native_compute;

OrtStatus *m3_ci_compute_get_capability(const OrtApi *, const OrtEpApi *,
                                        const OrtGraph *, OrtEpGraphSupportInfo *);
OrtStatus *ORT_API_CALL m3_ci_compute_compile(OrtEp *, const OrtGraph **,
    const OrtNode **, size_t, OrtNodeComputeInfo **, OrtNode **);
void ORT_API_CALL m3_ci_compute_release_infos(OrtEp *, OrtNodeComputeInfo **,
                                               size_t);
static const char provider_name[] = "VulpraCIProbeEP";
static const char vendor_name[] = "Vulpra CI fixture";
static const char fixture_version[] = "0.0.1";

static const char *ORT_API_CALL get_name(const OrtEpFactory *factory) {
  (void)factory;
  fputs("M3_EP_CALLBACK=get_name\n", stderr); fflush(stderr);
  return provider_name;
}

static const char *ORT_API_CALL get_vendor(const OrtEpFactory *factory) {
  (void)factory;
  fputs("M3_EP_CALLBACK=get_vendor\n", stderr); fflush(stderr);
  return vendor_name;
}

// This test plugin claims NO real hardware or supported OrtEpDevice.
static uint32_t ORT_API_CALL get_vendor_id(const OrtEpFactory *factory) {
  (void)factory;
  fputs("M3_EP_CALLBACK=get_vendor_id\n", stderr); fflush(stderr);
  return 0;  // CI fixture, no PCI hardware vendor.
}

static const char *ORT_API_CALL get_version(const OrtEpFactory *factory) {
  (void)factory;
  fputs("M3_EP_CALLBACK=get_version\n", stderr); fflush(stderr);
  return fixture_version;
}

static OrtStatus *ORT_API_CALL get_supported_devices(
    OrtEpFactory *factory, const OrtHardwareDevice *const *devices,
    size_t device_count, OrtEpDevice **ep_devices, size_t max_ep_devices,
    size_t *num_ep_devices) {
  (void)factory;
  (void)devices;
  (void)device_count;
  (void)ep_devices;
  (void)max_ep_devices;
  fputs("M3_EP_CALLBACK=get_supported_devices\n", stderr); fflush(stderr);
  if (num_ep_devices == NULL) {
    return runtime_api != NULL
               ? runtime_api->CreateStatus(ORT_INVALID_ARGUMENT, "missing count")
               : NULL;
  }
  *num_ep_devices = 0;
  if (!enumerate_ci_cpu_device) {
    return NULL;
  }
  // Only a CPU device already discovered by ORT can be advertised.
  // No synthetic GPU or accelerator is invented by this CI fixture.
  if (runtime_api == NULL || runtime_ep_api == NULL ||
      runtime_api->HardwareDevice_Type == NULL ||
      runtime_ep_api->CreateEpDevice == NULL || devices == NULL ||
      ep_devices == NULL || max_ep_devices == 0) {
    return runtime_api != NULL
               ? runtime_api->CreateStatus(ORT_FAIL, "CPU probe prerequisites missing")
               : NULL;
  }
  for (size_t i = 0; i < device_count; ++i) {
    if (devices[i] == NULL ||
        runtime_api->HardwareDevice_Type(devices[i]) != OrtHardwareDeviceType_CPU) {
      continue;
    }
    OrtEpDevice *created = NULL;
    OrtStatus *status =
        runtime_ep_api->CreateEpDevice(factory, devices[i], NULL, NULL, &created);
    if (status != NULL) {
      return status;
    }
    if (created == NULL) {
      return runtime_api->CreateStatus(ORT_FAIL, "CreateEpDevice returned NULL");
    }
    ep_devices[0] = created;  // ORT owns the created device.
    *num_ep_devices = 1;
    fputs("M3_EP_CALLBACK=cpu_ep_device_created\n", stderr); fflush(stderr);
    return NULL;
  }
  return runtime_api->CreateStatus(ORT_FAIL, "No discovered CPU hardware device");
}

// Session fixture: fallback declines all nodes; opt-in compute claims one Mul.
static const char *ORT_API_CALL ep_get_name(const OrtEp *ep) {
  (void)ep;
  return provider_name;
}

static OrtStatus *ORT_API_CALL ep_get_capability(
    OrtEp *ep, const OrtGraph *graph, OrtEpGraphSupportInfo *support) {
  (void)ep;
  if (enable_ci_native_compute) {
    return m3_ci_compute_get_capability(runtime_api, runtime_ep_api, graph, support);
  }
  (void)graph;
  (void)support;  // CPU fallback mode does not claim anything.
  fputs("M3_EP_CALLBACK=get_capability_no_nodes\n", stderr); fflush(stderr);
  return NULL;
}

// Session modes expose either a non-executing fallback EP or a bounded scalar-Mul EP.
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
  fputs("M3_EP_CALLBACK=create_ep\n", stderr); fflush(stderr);
  if (ep != NULL) {
    *ep = NULL;
  }
  if ((!enable_ci_cpu_fallback_session && !enable_ci_native_compute) || ep == NULL) {
    return runtime_api != NULL
               ? runtime_api->CreateStatus(ORT_NOT_IMPLEMENTED,
                                           "CI fixture does not execute models")
               : NULL;
  }
  OrtEp *instance = (OrtEp *)calloc(1, sizeof(*instance));
  if (instance == NULL) {
    return runtime_api->CreateStatus(ORT_FAIL, "CI OrtEp allocation failed");
  }
  instance->ort_version_supported = ORT_API_VERSION;
  instance->GetName = ep_get_name;
  instance->GetCapability = ep_get_capability;
  if (enable_ci_native_compute) {
    instance->Compile = m3_ci_compute_compile;
    instance->ReleaseNodeComputeInfos = m3_ci_compute_release_infos;
  }
  *ep = instance;
  fputs("M3_EP_CALLBACK=session_ep_created\n", stderr); fflush(stderr);
  return NULL;
}

static void ORT_API_CALL release_ep(OrtEpFactory *factory, OrtEp *ep) {
  (void)factory;
  free(ep);  // ORT releases all sessions before registration teardown.
  fputs("M3_EP_CALLBACK=release_ep\n", stderr); fflush(stderr);
}

static OrtStatus *ORT_API_CALL create_data_transfer(
    OrtEpFactory *factory, OrtDataTransferImpl **transfer) {
  (void)factory;
  fputs("M3_EP_CALLBACK=create_data_transfer\n", stderr);
  fflush(stderr);
  if (transfer != NULL) {
    *transfer = NULL;  // This factory has no hardware or transport.
  }
  return NULL;
}

static OrtEpFactory *make_factory(void) {
  OrtEpFactory *factory = (OrtEpFactory *)calloc(1, sizeof(*factory));
  if (factory == NULL) {
    return NULL;
  }
  factory->ort_version_supported = ORT_API_VERSION;
  factory->GetName = get_name;
  factory->GetVendor = get_vendor;
  factory->GetVendorId = get_vendor_id;
  factory->GetVersion = get_version;
  factory->GetSupportedDevices = get_supported_devices;
  factory->CreateEp = create_ep;
  factory->ReleaseEp = release_ep;
  factory->CreateDataTransfer = create_data_transfer;
  return factory;
}

#if defined(__GNUC__)
#define M3_EXPORT __attribute__((visibility("default")))
#else
#define M3_EXPORT
#endif

M3_EXPORT OrtStatus *CreateEpFactories(
    const char *registered_name, const OrtApiBase *api_base,
    const OrtLogger *default_logger, OrtEpFactory **factories,
    size_t max_factories, size_t *num_factories) {
  (void)default_logger;
  fputs("M3_EP_CALLBACK=entered_factory_init\n", stderr);
  fflush(stderr);
  /* Never dereference shifted arguments if the compiled EP ABI differs. */
  if (max_factories > 8 || (uintptr_t)num_factories < 4096 ||
      (uintptr_t)factories < 4096 || (uintptr_t)api_base < 4096) {
    fputs("M3_EP_DIAGNOSTIC=plugin_callback_signature_mismatch\n", stderr);
    fflush(stderr);
    _Exit(77);
  }
  fputs("M3_EP_CALLBACK=argument_shape_plausible\n", stderr);
  fflush(stderr);
  const OrtApi *fallback = api_base->GetApi(1);
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
  fputs("M3_EP_CALLBACK=before_api30\n", stderr);
  fflush(stderr);
  const OrtApi *api30 = api_base->GetApi(ORT_API_VERSION);
  if (api30 == NULL) {
    return fallback != NULL
               ? fallback->CreateStatus(ORT_NOT_IMPLEMENTED,
                                        "ORT API v30 required")
               : NULL;
  }
  OrtEpFactory *factory = make_factory();
  if (factory == NULL) {
    return api30->CreateStatus(ORT_FAIL, "CI factory allocation failed");
  }
  runtime_api = api30;
  const char *device_mode = getenv("VULPRA_CI_ONNX_EP_DEVICE_PROBE");
  const char *session_mode = getenv("VULPRA_CI_ONNX_EP_CPU_FALLBACK");
  enable_ci_cpu_fallback_session =
      session_mode != NULL && strcmp(session_mode, "1") == 0;
  const char *compute_mode = getenv("VULPRA_CI_ONNX_EP_NATIVE_COMPUTE");
  const char *mixed_mode = getenv("VULPRA_CI_ONNX_EP_MIXED_COMPUTE");
  enable_ci_native_compute =
      (compute_mode != NULL && strcmp(compute_mode, "1") == 0) ||
      (mixed_mode != NULL && strcmp(mixed_mode, "1") == 0);
  enumerate_ci_cpu_device =
      (device_mode != NULL && strcmp(device_mode, "1") == 0) ||
      enable_ci_cpu_fallback_session || enable_ci_native_compute;
  runtime_ep_api = api30->GetEpApi != NULL ? api30->GetEpApi() : NULL;
  if (enumerate_ci_cpu_device && runtime_ep_api == NULL) {
    free(factory);
    return api30->CreateStatus(ORT_FAIL, "OrtEpApi unavailable");
  }
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
  if (factory == NULL || factory->ort_version_supported != 30 ||
      factory->GetName == NULL || factory->GetVendor == NULL ||
      factory->GetVendorId == NULL || factory->GetVersion == NULL ||
      factory->GetSupportedDevices == NULL || factory->CreateEp == NULL ||
      factory->ReleaseEp == NULL || factory->CreateDataTransfer == NULL ||
      strcmp(factory->GetName(factory), provider_name) != 0 ||
      strcmp(factory->GetVendor(factory), vendor_name) != 0 ||
      factory->GetVendorId(factory) != 0 ||
      strcmp(factory->GetVersion(factory), fixture_version) != 0) {
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
