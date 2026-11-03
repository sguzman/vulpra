/* One-shot ONNX custom-ops registration fixture, intentionally registers
 * ZERO operators. The only side effect is a bounded counter proving ONNX
 * Runtime called this function through its own shared-library API.
 * No entrypoints, networking, filesystem, environment or user state.
 * Build -shared -fPIC, use exclusively inside disposable CI netns.
 */
#include <stdint.h>

__attribute__((visibility("default")))
uint32_t m3_customops_callback_count = 0;

__attribute__((visibility("default")))
void *RegisterCustomOps(void *options, const void *api_base) {
  if (options != 0 && api_base != 0 &&
      m3_customops_callback_count == 0) {
    ++m3_customops_callback_count;
  }
  return 0; /* OrtStatus* success; register no custom operators */
}
