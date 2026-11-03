/* Intentionally inert original-ONNX v22 EP plugin fixture for isolated CI.
 * Implements exact ABI exports, returns ZERO provider factories/devices and
 * never reads files, touches a user system or registers a usable EP.
 * Header is pinned upstream and compiled in CI, not vendored in Vulpra.
 */
#include <stdint.h>
#include <unistd.h>
#include "onnxruntime_c_api.h"

/* Fixed stage markers only, no paths, addresses, or caller arguments. */
__attribute__((constructor))
static void m3_ep_loaded_marker(void) {
  static const char msg[] = "M3_EP_FIXTURE=loaded\n";
  (void)write(2, msg, sizeof(msg) - 1);
}

__attribute__((visibility("default")))
uint32_t m3_ep_factory_call_count = 0;

__attribute__((visibility("default")))
OrtStatus* CreateEpFactories(const char* registration_name,
                             const OrtApiBase* base,
                             OrtEpFactory** factories,
                             size_t max_factories,
                             size_t* num_factories) {
  static const char msg[] = "M3_EP_FIXTURE=create_ep_factories_called\n";
  (void)write(2, msg, sizeof(msg) - 1);
  if (registration_name == 0 || base == 0 || factories == 0 ||
      max_factories == 0 || num_factories == 0 ||
      m3_ep_factory_call_count != 0) {
    /* The caller treats a null status as successful registration. This
       fixture is never used with intentionally invalid arguments. */
    return 0;
  }
  ++m3_ep_factory_call_count;
  *num_factories = 0;
  return 0;
}

__attribute__((visibility("default")))
OrtStatus* ReleaseEpFactory(OrtEpFactory* factory) {
  (void)factory;
  return 0;
}
