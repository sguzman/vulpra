// Original source-authenticated inline GbmLib::CreateWithModifiers2 body
// is extracted *verbatim* from widget/gtk/DMABufDevice.h and included in
// this stand-alone ABI-shaped mock runtime. This is not packaged Vulpra,
// a real GBM library ABI test, or a DMABuf buffer/rendering test.
#include <cstdint>
#include <cstdio>
#include <cstring>

struct gbm_device { int id; };
struct gbm_bo { int id; };
using CreateWithModifiersFunc =
    gbm_bo* (*)(gbm_device*, uint32_t, uint32_t, uint32_t,
                const uint64_t*, const unsigned int);
using CreateWithModifiers2Func =
    gbm_bo* (*)(gbm_device*, uint32_t, uint32_t, uint32_t,
                const uint64_t*, const unsigned int, const uint32_t);

class GbmLib {
 public:
  static CreateWithModifiersFunc sCreateWithModifiers;
  static CreateWithModifiers2Func sCreateWithModifiers2;
#include "real-gbm-inline-create-with-modifiers2.inc"
};
CreateWithModifiersFunc GbmLib::sCreateWithModifiers=nullptr;
CreateWithModifiers2Func GbmLib::sCreateWithModifiers2=nullptr;

static gbm_device device{10};
static gbm_bo old_bo{20};
static gbm_bo newer_bo{30};
static const uint64_t modifiers[]={0x123456789ULL,0x987654321ULL};
static const uint32_t width=640, height=480, format=0x34325241, flags=0x5;
static int old_calls=0, new_calls=0, bad_args=0;
static bool old_returns_null=false, new_returns_null=false;

static bool valid_args(gbm_device* d, uint32_t w, uint32_t h, uint32_t f,
                       const uint64_t* mods, unsigned int count) {
  return d==&device && w==width && h==height && f==format &&
         mods==modifiers && count==2;
}
static gbm_bo* old_create(gbm_device* d, uint32_t w, uint32_t h, uint32_t f,
                          const uint64_t* mods, unsigned int count) {
  ++old_calls;
  if (!valid_args(d,w,h,f,mods,count)) ++bad_args;
  return old_returns_null?nullptr:&old_bo;
}
static gbm_bo* new_create(gbm_device* d, uint32_t w, uint32_t h, uint32_t f,
                          const uint64_t* mods, unsigned int count,
                          uint32_t received_flags) {
  ++new_calls;
  if (!valid_args(d,w,h,f,mods,count) || received_flags!=flags) ++bad_args;
  return new_returns_null?nullptr:&newer_bo;
}
static int fail(const char* name, const char* reason) {
  std::fprintf(stderr,"FAIL: %s: %s\n",name,reason);
  return 1;
}
int main(int argc, char** argv) {
  if (argc!=2) {
    std::fputs("usage: fixture null-device|older-api-fallback|newer-api-preferred|older-api-failure|newer-api-failure\n",stderr);
    return 2;
  }
  const char* name=argv[1];
  gbm_device* arg=&device;
  gbm_bo* expected=nullptr;
  int want_old=0, want_new=0;
  GbmLib::sCreateWithModifiers=&old_create;
  GbmLib::sCreateWithModifiers2=&new_create;
  if (!std::strcmp(name,"null-device")) {
    arg=nullptr;
    GbmLib::sCreateWithModifiers=nullptr;
    GbmLib::sCreateWithModifiers2=nullptr;
  } else if (!std::strcmp(name,"older-api-fallback")) {
    GbmLib::sCreateWithModifiers2=nullptr;
    expected=&old_bo; want_old=1;
  } else if (!std::strcmp(name,"newer-api-preferred")) {
    expected=&newer_bo; want_new=1;
  } else if (!std::strcmp(name,"older-api-failure")) {
    GbmLib::sCreateWithModifiers2=nullptr;
    old_returns_null=true; want_old=1;
  } else if (!std::strcmp(name,"newer-api-failure")) {
    new_returns_null=true; want_new=1;
  } else {
    return fail(name,"unsupported test mode");
  }
  // Executes the original source-owned inline C++ wrapper, not a copy.
  gbm_bo* observed=GbmLib::CreateWithModifiers2(
      arg,width,height,format,modifiers,2,flags);
  if (observed!=expected) return fail(name,"incorrect returned gbm_bo pointer");
  if (old_calls!=want_old || new_calls!=want_new)
    return fail(name,"wrong old/new GBM ABI callback count");
  if (bad_args) return fail(name,"source wrapper dropped or altered ABI arguments");
  std::printf(
    "{\"mode\":\"%s\","
    "\"original_source_inline_wrapper_executed\":true,"
    "\"provider_symbols_mocked\":true,"
    "\"old_modifiers_api_calls\":%d,"
    "\"new_modifiers2_api_calls\":%d,"
    "\"null_result\":%s,"
    "\"missing_optional_api_old_fallback_executed\":%s,"
    "\"actual_gbm_library_used\":false,"
    "\"actual_dmabuf_buffer_created\":false,"
    "\"packaged_browser_gpu_fallback_verified\":false}\n",
    name,old_calls,new_calls,observed?"false":"true",
    (!std::strcmp(name,"older-api-fallback")||!std::strcmp(name,"older-api-failure"))?"true":"false");
  return 0;
}
