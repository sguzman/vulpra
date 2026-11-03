// CI-only ONNX v30 external-EP session and numerical tests.
// Builds runtime-input Identity (CPU fallback) or Mul (native external EP).
#include "onnxruntime_c_api.h"
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#if ORT_API_VERSION != 30
#error "This source requires the pinned ONNX Runtime v30 C API"
#endif

typedef struct {
  uint8_t data[512];
  size_t len;
  int ok;
} M3Buf;

static M3Buf buf_new(void) {
  M3Buf b = {{0}, 0, 1};
  return b;
}
static void buf_byte(M3Buf *b, uint8_t value) {
  if (!b->ok || b->len >= sizeof(b->data)) { b->ok = 0; return; }
  b->data[b->len++] = value;
}
static void buf_varint(M3Buf *b, uint64_t n) {
  while (n >= 128) {
    buf_byte(b, (uint8_t)((n & 127) | 128));
    n >>= 7;
  }
  buf_byte(b, (uint8_t)n);
}
static void buf_bytes(M3Buf *b, const void *bytes, size_t n) {
  if (!b->ok || n > sizeof(b->data) - b->len) { b->ok = 0; return; }
  memcpy(b->data + b->len, bytes, n);
  b->len += n;
}
static void field_var(M3Buf *b, uint64_t field, uint64_t value) {
  buf_varint(b, field * 8);
  buf_varint(b, value);
}
static void field_bytes(M3Buf *b, uint64_t field, const void *data, size_t size) {
  buf_varint(b, field * 8 + 2);
  buf_varint(b, size);
  buf_bytes(b, data, size);
}
static void field_sub(M3Buf *b, uint64_t field, const M3Buf *sub) {
  if (!sub->ok) { b->ok = 0; return; }
  field_bytes(b, field, sub->data, sub->len);
}
static M3Buf input_model(int plugin_mul) {
  M3Buf node = buf_new();
  field_bytes(&node, 1, "x", 1);
  if (plugin_mul) field_bytes(&node, 1, "z", 1);
  field_bytes(&node, 2, "y", 1);
  field_bytes(&node, 4, plugin_mul ? "Mul" : "Identity", plugin_mul ? 3 : 8);

  M3Buf dim = buf_new(); field_var(&dim, 1, 1);
  M3Buf shape = buf_new(); field_sub(&shape, 1, &dim);
  M3Buf tensor_ty = buf_new();
  field_var(&tensor_ty, 1, 1); // FLOAT
  field_sub(&tensor_ty, 2, &shape);
  M3Buf value_ty = buf_new(); field_sub(&value_ty, 1, &tensor_ty);

  M3Buf input = buf_new();
  field_bytes(&input, 1, "x", 1);
  field_sub(&input, 2, &value_ty);
  M3Buf output = buf_new();
  field_bytes(&output, 1, "y", 1);
  field_sub(&output, 2, &value_ty);

  M3Buf graph = buf_new();
  field_sub(&graph, 1, &node);
  field_bytes(&graph, 2, "single-identity", 15);
  field_sub(&graph, 11, &input);
  if (plugin_mul) {
    M3Buf second_graph_input = buf_new();
    field_bytes(&second_graph_input, 1, "z", 1);
    field_sub(&second_graph_input, 2, &value_ty);
    field_sub(&graph, 11, &second_graph_input);
  }
  field_sub(&graph, 12, &output);
  M3Buf opset = buf_new(); field_var(&opset, 2, 13);
  M3Buf model = buf_new();
  field_var(&model, 1, 8);
  field_bytes(&model, 2, "vulpra-isolated-native-fixture", 30);
  field_sub(&model, 7, &graph);
  field_sub(&model, 8, &opset);
  return model;
}

static int checked(const OrtApi *api, OrtStatus *status, const char *stage) {
  if (status == NULL) return 1;
  fprintf(stderr, "M3_EP_ERROR_STAGE=%s code=%d detail=%.240s\n",
          stage, (int)api->GetErrorCode(status), api->GetErrorMessage(status));
  api->ReleaseStatus(status);
  return 0;
}

static int m3_probe_session(const OrtApi *api, OrtEnv *env,
                            const OrtEpDevice *device, int plugin_mul) {
  if (api == NULL || env == NULL || device == NULL) return 1;
  int ok = 0;
  OrtSessionOptions *opts = NULL;
  OrtSession *session = NULL;
  OrtValue *output = NULL;
  OrtValue *input = NULL;
  OrtValue *second_input = NULL;
  OrtMemoryInfo *memory = NULL;
  OrtTensorTypeAndShapeInfo *shape = NULL;
  if (!checked(api, api->CreateSessionOptions(&opts), "session_options") || opts == NULL)
    goto done;
  if (!checked(api, api->SetSessionGraphOptimizationLevel(opts, ORT_DISABLE_ALL),
               "disable_constant_folding")) goto done;
  const OrtEpDevice *selected[1] = {device};
  if (!checked(api, api->SessionOptionsAppendExecutionProvider_V2(
                   opts, env, selected, 1, NULL, NULL, 0), "append_fixture_ep"))
    goto done;
  puts("M3_EP_STAGE=external_ep_appended"); fflush(stdout);
  M3Buf model = input_model(plugin_mul);
  if (!model.ok || model.len < 45 || model.len > 512) {
    fputs("M3_EP_ERROR_STAGE=model_encoding\n", stderr);
    goto done;
  }
  if (!checked(api, api->CreateSessionFromArray(
                   env, model.data, model.len, opts, &session), "create_session") ||
      session == NULL) goto done;
  puts("M3_EP_STAGE=external_ep_session_created"); fflush(stdout);
  if (!checked(api, api->CreateCpuMemoryInfo(OrtArenaAllocator, OrtMemTypeDefault,
                                                &memory), "cpu_memory_info") ||
      memory == NULL) goto done;
  int64_t dims[1] = {1};
  float input_value = 1.25f;
  if (!checked(api, api->CreateTensorWithDataAsOrtValue(
                   memory, &input_value, sizeof(input_value),
                   dims, 1, ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT, &input),
               "input_tensor") || input == NULL) goto done;
  const char *input_names[2] = {"x", "z"};
  const OrtValue *input_values[2] = {input, NULL};
  size_t input_count = 1;
  float second_value = 1.25f;
  if (plugin_mul) {
    if (!checked(api, api->CreateTensorWithDataAsOrtValue(
                     memory, &second_value, sizeof(second_value),
                     dims, 1, ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT, &second_input),
                 "second_input_tensor") || second_input == NULL) goto done;
    input_values[1] = second_input;
    input_count = 2;
  }
  const char *output_names[1] = {"y"};
  if (!checked(api, api->Run(session, NULL, input_names, input_values, input_count,
                             output_names, 1, &output),
               plugin_mul ? "native_ep_run" : "cpu_fallback_run") ||
      output == NULL) goto done;
  if (!checked(api, api->GetTensorTypeAndShape(output, &shape),
               "output_shape") || shape == NULL) goto done;
  ONNXTensorElementDataType type = ONNX_TENSOR_ELEMENT_DATA_TYPE_UNDEFINED;
  size_t count = 0;
  int64_t dim = 0;
  if (!checked(api, api->GetTensorElementType(shape, &type), "output_type") ||
      !checked(api, api->GetDimensionsCount(shape, &count), "output_rank") ||
      count != 1 ||
      !checked(api, api->GetDimensions(shape, &dim, 1), "output_dims") ||
      type != ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT || dim != 1) goto done;
  void *ptr = NULL;
  if (!checked(api, api->GetTensorMutableData(output, &ptr), "output_data") ||
      ptr == NULL) goto done;
  float value = 0.0f;
  memcpy(&value, ptr, sizeof(value));
  float expected = plugin_mul ? 1.5625f : 1.25f;
  if (value != expected) {
    fprintf(stderr, "M3_EP_ERROR_STAGE=wrong_numeric_result value=%f expected=%f\n",
            value, expected);
    goto done;
  }
  if (plugin_mul) {
    puts("M3_EP_STAGE=external_ep_numerical_result_1_5625"); fflush(stdout);
  } else {
    puts("M3_EP_STAGE=cpu_fallback_numerical_result_1_25"); fflush(stdout);
  }
  ok = 1;
done:
  if (shape != NULL) api->ReleaseTensorTypeAndShapeInfo(shape);
  if (output != NULL) api->ReleaseValue(output);
  if (input != NULL) api->ReleaseValue(input);
  if (second_input != NULL) api->ReleaseValue(second_input);
  if (memory != NULL) api->ReleaseMemoryInfo(memory);
  if (session != NULL) api->ReleaseSession(session);
  if (opts != NULL) api->ReleaseSessionOptions(opts);
  return ok ? 0 : 1;
}

int m3_probe_cpu_fallback_session(const OrtApi *api, OrtEnv *env,
                                  const OrtEpDevice *device) {
  return m3_probe_session(api, env, device, 0);
}

int m3_probe_external_ep_compute_session(const OrtApi *api, OrtEnv *env,
                                         const OrtEpDevice *device) {
  return m3_probe_session(api, env, device, 1);
}
