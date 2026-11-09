// Isolated runtime fixture. Compile the REAL, blob-verified upstream C++
// VA-API / GBM function bodies extracted verbatim by the Rust tool. Only
// external NSPR/posix loader APIs, hardware guards and provider symbols are
// mocked; no Vulpra binary/profile/system libraries are modified.
// This is NOT evidence that the packaged Vulpra browser safely falls back.
#include <cassert>
#include <cstdio>
#include <cstring>
#include <cstdint>
#include <cstdlib>

enum class Mode {
  VaGuardNoHw, VaGuardNoRdd, VaMissingDrm, VaMissingVa,
  VaMissingSymbol, VaPresent,
  GbmMissingGbm, GbmMissingDrm, GbmMissingSymbol, GbmMissingOptionalModifier, GbmPresent
};
static Mode mode;
static int pr_loads=0, dlopen_calls=0, unload_calls=0, link_calls=0;
static int sym_calls=0;
static int forced_missing_symbol_lookups=0;
static const char* missing_gbm_symbol="gbm_create_device";
// Exactly the 18 nonnull fields in real GbmLib::IsLoaded(), whose original
// method is included below verbatim from source-verified DMABufDevice.cpp.
static const char* const required_gbm_symbols[]={
  "gbm_create_device", "gbm_device_destroy", "gbm_bo_create",
  "gbm_bo_create_with_modifiers", "gbm_bo_get_modifier",
  "gbm_bo_get_stride", "gbm_bo_get_fd", "gbm_bo_destroy",
  "gbm_bo_map", "gbm_bo_unmap", "gbm_bo_get_plane_count",
  "gbm_bo_get_handle_for_plane", "gbm_bo_get_stride_for_plane",
  "gbm_bo_get_offset", "gbm_device_is_format_supported",
  "drmPrimeHandleToFD", "gbm_surface_create", "gbm_surface_destroy"
};
static bool enable_hw=true, is_rdd=true;
static int pointer_a=1, pointer_b=2;
static void* const handle_a=&pointer_a;
static void* const handle_b=&pointer_b;

namespace gfx {
struct gfxVars {
  static bool CanUseHardwareVideoDecoding() { return enable_hw; }
};
}
static bool XRE_IsRDDProcess() { return is_rdd; }
static const int PR_LibSpec_Pathname=1;
static const int PR_LD_NOW=2, PR_LD_LOCAL=4;
struct PRLibSpec {
  int type=0;
  struct { const char* pathname=nullptr; } value;
};
static void* mocked_pr_load(PRLibSpec spec, int flags) {
  ++pr_loads;
  assert(spec.type==PR_LibSpec_Pathname);
  assert(flags==(PR_LD_NOW | PR_LD_LOCAL));
  if (std::strcmp(spec.value.pathname,"libva-drm.so.2")==0) {
    return mode==Mode::VaMissingDrm?nullptr:handle_a;
  }
  assert(std::strcmp(spec.value.pathname,"libva.so.2")==0);
  return mode==Mode::VaMissingVa?nullptr:handle_b;
}
static void* mocked_find_symbol(void*, const char* symbol) {
  ++sym_calls;
  assert(std::strcmp(symbol,"vaExportSurfaceHandle")==0);
  return mode==Mode::VaMissingSymbol?nullptr:handle_a;
}
static void mocked_unload_library(void* ptr) {
  ++unload_calls;
  assert(ptr==handle_b);
}
#define PR_LoadLibraryWithFlags(spec,flags) mocked_pr_load((spec),(flags))
#define PR_FindSymbol(handle,sym) mocked_find_symbol((handle),(sym))
#define PR_UnloadLibrary(handle) mocked_unload_library((handle))
#define FFMPEGP_LOG(...) ((void)0)

class VALibWrapper {
 public:
  void* mVALibDrm=nullptr;
  void* mVALib=nullptr;
  void Link() { ++link_calls; }
  bool LinkVAAPILibs();
};
// Verified unchanged source-compiled actual method body, NOT reimplemented.
#include "real-vaapi-loader.inc"

static void* mocked_dlopen(const char* name, int flags) {
  ++dlopen_calls;
  assert(flags==1); // RTLD_LAZY | RTLD_LOCAL from the exact original source
  if (std::strcmp(name,"libgbm.so.1")==0) {
    return mode==Mode::GbmMissingGbm?nullptr:handle_a;
  }
  assert(std::strcmp(name,"libdrm.so.2")==0);
  return mode==Mode::GbmMissingDrm?nullptr:handle_b;
}
static void* mocked_dlsym(void*, const char* symbol) {
  ++sym_calls;
  if (mode==Mode::GbmMissingSymbol &&
      std::strcmp(symbol,missing_gbm_symbol)==0) {
    ++forced_missing_symbol_lookups;
    return nullptr;
  }
  if (mode==Mode::GbmMissingOptionalModifier &&
      std::strcmp(symbol,"gbm_bo_create_with_modifiers2")==0) {
    ++forced_missing_symbol_lookups;
    return nullptr;
  }
  return handle_a;
}
#define RTLD_LAZY 1
#define RTLD_LOCAL 0
#define GBMLIB_NAME "libgbm.so.1"
#define DRMLIB_NAME "libdrm.so.2"
#define dlopen(name,flags) mocked_dlopen((name),(flags))
#define dlsym(handle,sym) mocked_dlsym((handle),(sym))
#define LOGDMABUF(...) ((void)0)
#define MOZ_ASSERT(expr) assert((expr))

using CreateDeviceFunc=void*;
using DestroyDeviceFunc=void*;
using CreateFunc=void*;
using CreateWithModifiersFunc=void*;
using CreateWithModifiers2Func=void*;
using GetModifierFunc=void*;
using GetStrideFunc=void*;
using GetFdFunc=void*;
using DestroyFunc=void*;
using MapFunc=void*;
using UnmapFunc=void*;
using GetPlaneCountFunc=void*;
using GetHandleForPlaneFunc=void*;
using GetStrideForPlaneFunc=void*;
using GetOffsetFunc=void*;
using DeviceIsFormatSupportedFunc=void*;
using DrmPrimeHandleToFDFunc=void*;
using CreateSurfaceFunc=void*;
using DestroySurfaceFunc=void*;

class GbmLib {
 public:
  inline static bool sLoaded=false;
  inline static void* sGbmLibHandle=nullptr;
  inline static void* sXf86DrmLibHandle=nullptr;
  inline static void* sCreateDevice=nullptr;
  inline static void* sDestroyDevice=nullptr;
  inline static void* sCreate=nullptr;
  inline static void* sCreateWithModifiers=nullptr;
  inline static void* sCreateWithModifiers2=nullptr;
  inline static void* sGetModifier=nullptr;
  inline static void* sGetStride=nullptr;
  inline static void* sGetFd=nullptr;
  inline static void* sDestroy=nullptr;
  inline static void* sMap=nullptr;
  inline static void* sUnmap=nullptr;
  inline static void* sGetPlaneCount=nullptr;
  inline static void* sGetHandleForPlane=nullptr;
  inline static void* sGetStrideForPlane=nullptr;
  inline static void* sGetOffset=nullptr;
  inline static void* sDeviceIsFormatSupported=nullptr;
  inline static void* sDrmPrimeHandleToFD=nullptr;
  inline static void* sCreateSurface=nullptr;
  inline static void* sDestroySurface=nullptr;
  static bool IsLoaded();
  static bool Load();
};
#include "real-gbm-is-loaded.inc"
#include "real-gbm-load.inc"

static int fail(const char* scenario, const char* reason) {
  std::fprintf(stderr, "FAIL: %s: %s\n", scenario, reason);
  return 1;
}
static Mode decode(const char* s) {
  struct Entry { const char* name; Mode value; };
  static const Entry names[]={
    {"va-no-hw",Mode::VaGuardNoHw}, {"va-no-rdd",Mode::VaGuardNoRdd},
    {"va-no-drm",Mode::VaMissingDrm}, {"va-no-va",Mode::VaMissingVa},
    {"va-no-symbol",Mode::VaMissingSymbol}, {"va-present",Mode::VaPresent},
    {"gbm-no-gbm",Mode::GbmMissingGbm}, {"gbm-no-drm",Mode::GbmMissingDrm},
    {"gbm-no-symbol",Mode::GbmMissingSymbol}, {"gbm-present",Mode::GbmPresent},
    {"gbm-no-optional-modifier2",Mode::GbmMissingOptionalModifier}
  };
  for (const auto& e : names) if (std::strcmp(s,e.name)==0) return e.value;
  const char* const prefix="gbm-no-required-";
  if (std::strncmp(s,prefix,std::strlen(prefix))==0) {
    const char* symbol=s+std::strlen(prefix);
    for (const char* required : required_gbm_symbols) {
      if (std::strcmp(required,symbol)==0) {
        missing_gbm_symbol=required;
        return Mode::GbmMissingSymbol;
      }
    }
  }
  std::fprintf(stderr, "FAIL: unrecognized mock-provider scenario %s\n",s);
  std::exit(2);
}
int main(int argc, char** argv) {
  if (argc!=2) { std::fprintf(stderr,"usage: fixture SCENARIO\n"); return 2; }
  const char* scenario=argv[1];
  mode=decode(scenario);
  enable_hw=mode!=Mode::VaGuardNoHw;
  is_rdd=mode!=Mode::VaGuardNoRdd;
  bool observed=false, expected=false;
  int expected_pr_loads=0, expected_unloads=0, expected_link=0;
  int expected_dlopen=0;
  bool gbm=std::strncmp(scenario,"gbm-",4)==0;
  if (!gbm) {
    VALibWrapper a;
    observed=a.LinkVAAPILibs();
    expected=(mode==Mode::VaPresent);
    switch (mode) {
      case Mode::VaGuardNoHw: case Mode::VaGuardNoRdd: expected_pr_loads=0; break;
      case Mode::VaMissingDrm: expected_pr_loads=1; break;
      default: expected_pr_loads=2; break;
    }
    expected_link=expected?1:0;
    expected_unloads=mode==Mode::VaMissingSymbol?1:0;
    if (a.mVALibDrm!=nullptr && mode==Mode::VaMissingDrm)
      return fail(scenario,"DRM unexpectedly loaded");
    if (a.mVALib!=nullptr && mode==Mode::VaMissingVa)
      return fail(scenario,"VA unexpectedly loaded");
  } else {
    observed=GbmLib::Load();
    expected=(mode==Mode::GbmPresent || mode==Mode::GbmMissingOptionalModifier);
    expected_dlopen=mode==Mode::GbmMissingGbm?1:2;
    const int before=dlopen_calls;
    const bool repeated=GbmLib::Load();
    if (repeated!=observed || dlopen_calls!=before)
      return fail(scenario,"one-shot GBM state/cache guard not preserved");
    if ((mode==Mode::GbmMissingSymbol || mode==Mode::GbmMissingOptionalModifier) &&
        forced_missing_symbol_lookups!=1)
      return fail(scenario,"requested dlsym symbol was not actually queried by original loader");
  }
  if (observed!=expected) return fail(scenario,"unexpected load boolean");
  if (pr_loads!=expected_pr_loads || dlopen_calls!=expected_dlopen ||
      unload_calls!=expected_unloads || link_calls!=expected_link)
    return fail(scenario,"unexpected loader/cleanup/linked-module call count");
  // All assertions above were evaluated for the exact source-extracted functions.
  std::printf(
    "{\"scenario\":\"%s\",\"source_extracted_cpp_function_executed\":true,"
    "\"provider_library_resolution_mocked\":true,"
    "\"observed_load\":%s,\"expected_load\":%s,"
    "\"pr_load_calls\":%d,\"dlopen_calls\":%d,"
    "\"unload_calls\":%d,\"link_calls\":%d,"
    "\"packaged_browser_feature_fallback_verified\":false}\n",
    scenario, observed?"true":"false",expected?"true":"false",
    pr_loads,dlopen_calls,unload_calls,link_calls);
   return 0;
}
