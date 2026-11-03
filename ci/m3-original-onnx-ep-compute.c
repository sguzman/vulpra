// Test-only, source-pinned ONNX 1.30 external execution provider arithmetic.
// This is NOT shipped in Vulpra: one fixed-shape CPU float32 Mul node only.
#include "onnxruntime_c_api.h"
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#if ORT_API_VERSION != 30
#error "The compute probe requires pinned ORT API v30"
#endif

static const OrtApi *ci_api;

static OrtStatus *ci_status(OrtErrorCode code, const char *msg) {
  return ci_api->CreateStatus(code, msg);
}

// Prefer propagating the genuine OrtStatus returned by the runtime.
OrtStatus *m3_ci_compute_get_capability(const OrtApi *api,
                                        const OrtEpApi *ep_api,
                                        const OrtGraph *graph,
                                        OrtEpGraphSupportInfo *support) {
  ci_api = api;
  if (api == NULL || ep_api == NULL || graph == NULL || support == NULL) {
    return ci_status(ORT_INVALID_ARGUMENT, "invalid compute capability arguments");
  }
  // Graph introspection is part of OrtApi (not OrtModelEditorApi) in v30.
  size_t count = 0;
  OrtStatus *st = api->Graph_GetNumNodes(graph, &count);
  if (st != NULL) return st;
  if (count != 1) return NULL; // Do not claim partial or unknown graphs.
  const OrtNode *node = NULL;
  st = api->Graph_GetNodes(graph, &node, 1);
  if (st != NULL) return st;
  const char *op = NULL, *domain = NULL;
  st = api->Node_GetOperatorType(node, &op);
  if (st != NULL) return st;
  st = api->Node_GetDomain(node, &domain);
  if (st != NULL) return st;
  if (op == NULL || strcmp(op, "Mul") != 0 ||
      (domain != NULL && domain[0] != '\0')) {
    return NULL;
  }
  const OrtNode *selected[1] = {node};
  st = ep_api->EpGraphSupportInfo_AddNodesToFuse(support, selected, 1, NULL);
  if (st == NULL) {
    fputs("M3_EP_CALLBACK=plugin_claimed_mul\n", stderr); fflush(stderr);
  }
  return st;
}

static OrtStatus *ORT_API_CALL ci_create_state(
    OrtNodeComputeInfo *info, OrtNodeComputeContext *context, void **state) {
  (void)context;
  if (state == NULL) return ci_status(ORT_INVALID_ARGUMENT, "missing compute state");
  *state = info; // No owned resources for a scalar Mul.
  fputs("M3_EP_CALLBACK=plugin_create_compute_state\n", stderr); fflush(stderr);
  return NULL;
}

static OrtStatus *ORT_API_CALL ci_compute(
    OrtNodeComputeInfo *info, void *state, OrtKernelContext *context) {
  if (state != info || context == NULL) {
    return ci_status(ORT_INVALID_ARGUMENT, "invalid scalar Mul state");
  }
  size_t inputs = 0, outputs = 0;
  OrtStatus *st = ci_api->KernelContext_GetInputCount(context, &inputs);
  if (st != NULL) return st;
  st = ci_api->KernelContext_GetOutputCount(context, &outputs);
  if (st != NULL) return st;
  if (inputs != 2 || outputs != 1) {
    return ci_status(ORT_INVALID_ARGUMENT, "expected 2 inputs and 1 output");
  }
  float values[2] = {0};
  for (size_t i = 0; i < 2; ++i) {
    const OrtValue *v = NULL;
    OrtTensorTypeAndShapeInfo *shape = NULL;
    st = ci_api->KernelContext_GetInput(context, i, &v);
    if (st != NULL) return st;
    if (v == NULL) return ci_status(ORT_INVALID_ARGUMENT, "missing Mul input");
    st = ci_api->GetTensorTypeAndShape(v, &shape);
    if (st != NULL) return st;
    ONNXTensorElementDataType dtype = ONNX_TENSOR_ELEMENT_DATA_TYPE_UNDEFINED;
    size_t rank = 0;
    size_t elements = 0;
    st = ci_api->GetTensorElementType(shape, &dtype);
    if (st == NULL) st = ci_api->GetDimensionsCount(shape, &rank);
    if (st == NULL) st = ci_api->GetTensorShapeElementCount(shape, &elements);
    ci_api->ReleaseTensorTypeAndShapeInfo(shape);
    if (st != NULL) return st;
    if (dtype != ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT || rank != 1 || elements != 1) {
      return ci_status(ORT_INVALID_ARGUMENT, "Mul fixture accepts float32[1] only");
    }
    const void *data = NULL;
    st = ci_api->GetTensorData(v, &data);
    if (st != NULL) return st;
    if (data == NULL) return ci_status(ORT_FAIL, "null Mul input data");
    memcpy(&values[i], data, sizeof(float));
  }
  const int64_t dims[1] = {1};
  OrtValue *out = NULL;
  st = ci_api->KernelContext_GetOutput(context, 0, dims, 1, &out);
  if (st != NULL) return st;
  if (out == NULL) return ci_status(ORT_FAIL, "null Mul output");
  void *p = NULL;
  st = ci_api->GetTensorMutableData(out, &p);
  if (st != NULL) return st;
  if (p == NULL) return ci_status(ORT_FAIL, "null Mul output tensor data");
  float result = values[0] * values[1];
  memcpy(p, &result, sizeof(result));
  fputs("M3_EP_CALLBACK=plugin_compute_mul\n", stderr); fflush(stderr);
  return NULL;
}

static void ORT_API_CALL ci_release_state(OrtNodeComputeInfo *info, void *state) {
  (void)info;
  (void)state;
  fputs("M3_EP_CALLBACK=plugin_release_compute_state\n", stderr); fflush(stderr);
}

OrtStatus *ORT_API_CALL m3_ci_compute_compile(
    OrtEp *instance, const OrtGraph **graphs, const OrtNode **fused_nodes,
    size_t count, OrtNodeComputeInfo **infos, OrtNode **ep_context_nodes) {
  (void)instance;
  (void)fused_nodes;
  if (graphs == NULL || infos == NULL || count != 1 || graphs[0] == NULL) {
    return ci_status(ORT_INVALID_ARGUMENT, "expected one compiled Mul graph");
  }
  OrtNodeComputeInfo *info = calloc(1, sizeof(*info));
  if (info == NULL) return ci_status(ORT_FAIL, "Mul compute allocation failed");
  info->ort_version_supported = ORT_API_VERSION;
  info->CreateState = ci_create_state;
  info->Compute = ci_compute;
  info->ReleaseState = ci_release_state;
  infos[0] = info;
  if (ep_context_nodes != NULL) ep_context_nodes[0] = NULL;
  fputs("M3_EP_CALLBACK=plugin_compile_mul\n", stderr); fflush(stderr);
  return NULL;
}

void ORT_API_CALL m3_ci_compute_release_infos(OrtEp *instance,
                                              OrtNodeComputeInfo **infos,
                                              size_t count) {
  (void)instance;
  for (size_t i = 0; i < count; ++i) free(infos[i]);
  fputs("M3_EP_CALLBACK=plugin_release_compute_infos\n", stderr); fflush(stderr);
}
