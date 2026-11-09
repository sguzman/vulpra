// Compile and RUN the verbatim source of the real FFmpegRuntimeLinker::Init()
// with fake NSPR library loading and FFmpegLibWrapper::Link(). The original
// sLibs array is separately included verbatim from the same authenticated
// Git blob. This is source control-flow evidence, NOT real browser playback.
// See ci/tests/m3-current-ffmpeg-linker-fixtures.sh for exact Git object proof.
#include <cassert>
#include <cstddef>
#include <cstdio>
#include <cstring>
#include <iterator>
#include <string>
#include <vector>

namespace mozilla {
struct StaticMutexAutoLock {
  explicit StaticMutexAutoLock(int&) {}
};
struct FFmpegLibWrapper {
  enum class LinkResult {
    Success, NoProvidedLib, NoAVCodecVersion, CannotUseLibAV57,
    BlockedOldLibAVVersion, UnknownFutureLibAVVersion,
    MissingLibAVFunction, UnknownFutureFFMpegVersion,
    MissingFFMpegFunction, UnknownOlderFFMpegVersion
  };
  void* mAVCodecLib=nullptr;
  void* mAVUtilLib=nullptr;
  int mVersion=62;
  static int link_calls, callback_calls;
  static LinkResult (*link_policy)(size_t);
  LinkResult Link();
  void RegisterCallbackLogLevel(void (*)(const char*,void*)) {
    ++callback_calls;
  }
  static const char* EnumValueToString(LinkResult) { return "mock"; }
};
int FFmpegLibWrapper::link_calls=0;
int FFmpegLibWrapper::callback_calls=0;
FFmpegLibWrapper::LinkResult (*FFmpegLibWrapper::link_policy)(size_t)=nullptr;

std::vector<std::string> attempted;
int codecs_initialized=0;
int encoders_initialized=0;
size_t successful_candidate=static_cast<size_t>(-1);
int mock_library=1;
using PRLibrary=void;
struct PRLibSpec { int type; struct {const char* pathname;} value; };
constexpr int PR_LibSpec_Pathname=1, PR_LD_NOW=2, PR_LD_LOCAL=4;
static PRLibrary* mocked_load(PRLibSpec spec, int flags) {
  assert(spec.type==PR_LibSpec_Pathname);
  assert(flags==(PR_LD_NOW|PR_LD_LOCAL));
  attempted.emplace_back(spec.value.pathname);
  if (attempted.size()-1==successful_candidate ||
      (FFmpegLibWrapper::link_policy && attempted.size()<=2))
    return &mock_library;
  return nullptr;
}
#define PR_LoadLibraryWithFlags(spec,flags) mocked_load((spec),(flags))
#define FFMPEGV_LOG(...) ((void)0)
#define FFMPEGP_LOG(...) ((void)0)
#define MOZ_ASSERT_UNREACHABLE(msg) assert(!msg)

class FFmpegRuntimeLinker {
 public:
  enum LinkStatus {
    LinkStatus_INIT=0,
    LinkStatus_SUCCEEDED,
    LinkStatus_INVALID_FFMPEG_CANDIDATE,
    LinkStatus_UNUSABLE_LIBAV57,
    LinkStatus_INVALID_LIBAV_CANDIDATE,
    LinkStatus_OBSOLETE_FFMPEG,
    LinkStatus_OBSOLETE_LIBAV,
    LinkStatus_INVALID_CANDIDATE,
    LinkStatus_NOT_FOUND
  };
  static int sMutex;
  static LinkStatus sLinkStatus;
  static const char* sLinkStatusLibraryName;
  static void PrefCallbackLogLevel(const char*,void*) {}
  static bool Init();
};
int FFmpegRuntimeLinker::sMutex=0;
FFmpegRuntimeLinker::LinkStatus FFmpegRuntimeLinker::sLinkStatus=
    FFmpegRuntimeLinker::LinkStatus_INIT;
const char* FFmpegRuntimeLinker::sLinkStatusLibraryName="";

template<int V> struct FFmpegDecoderModule {
  static void Init(const FFmpegLibWrapper*) { ++codecs_initialized; }
};
template<int V> struct FFmpegEncoderModule {
  static void Init(const FFmpegLibWrapper*) { ++encoders_initialized; }
};
static FFmpegLibWrapper sLibAV;

// FFMPEG_MAX_MAJOR_VERSION_STR in the authenticated upstream source is a
// compile-time generated macro. Here 63 is a mock fixture assumption only;
// the real browser's actual generated version and runtime ABI are not proven.
#define FFMPEG_MAX_MAJOR_VERSION 63
#define FFMPEG_MAX_MAJOR_VERSION_STR(value) "63"
#include "real-ffmpeg-loader-candidates.inc"
#include "real-ffmpeg-runtime-init.inc"

FFmpegLibWrapper::LinkResult FFmpegLibWrapper::Link() {
  ++link_calls;
  assert(link_policy);
  return link_policy(attempted.size()-1);
}
} // namespace mozilla

using namespace mozilla;
enum class Scenario { MissingAll, FirstSuccess, LastSuccess, BadThenSuccess,
                      InvalidPriority };
static Scenario active;
static FFmpegLibWrapper::LinkResult policy(size_t i) {
  using R=FFmpegLibWrapper::LinkResult;
  if (active==Scenario::InvalidPriority) {
    return i==0 ? R::NoAVCodecVersion : R::MissingFFMpegFunction;
  }
  if (active==Scenario::BadThenSuccess && i==0) {
    return R::MissingLibAVFunction;
  }
  return R::Success;
}
static int fail(const char* name,const char* why) {
  std::fprintf(stderr,"FAIL: %s: %s\n",name,why);
  return 1;
}
int main(int argc,char** argv) {
  if (argc!=2) return 2;
  const char* scenario=argv[1];
  bool expect_success=false;
  int want_link_calls=0, want_decoder_init=0;
  if (!std::strcmp(scenario,"missing-all")) {
    active=Scenario::MissingAll; successful_candidate=static_cast<size_t>(-1);
  } else if (!std::strcmp(scenario,"first-success")) {
    active=Scenario::FirstSuccess; successful_candidate=0;
    expect_success=true; want_link_calls=1; want_decoder_init=1;
  } else if (!std::strcmp(scenario,"last-success")) {
    active=Scenario::LastSuccess; successful_candidate=std::size(sLibs)-1;
    expect_success=true; want_link_calls=1; want_decoder_init=1;
  } else if (!std::strcmp(scenario,"bad-then-success")) {
    active=Scenario::BadThenSuccess; successful_candidate=1;
    expect_success=true; want_link_calls=2; want_decoder_init=1;
  } else if (!std::strcmp(scenario,"invalid-priority")) {
    active=Scenario::InvalidPriority; successful_candidate=static_cast<size_t>(-1);
    want_link_calls=2;
  } else return fail(scenario,"unrecognized fixture case");
  FFmpegLibWrapper::link_policy=(active==Scenario::MissingAll)?nullptr:policy;
  // Expected Linux candidate count = 14 entries in original source array.
  if (std::size(sLibs)!=14) return fail(scenario,"native Linux FFmpeg candidate count changed");
  bool actual=FFmpegRuntimeLinker::Init();
  const size_t first_calls=attempted.size();
  const auto status=FFmpegRuntimeLinker::sLinkStatus;
  const std::string status_library=FFmpegRuntimeLinker::sLinkStatusLibraryName;
  bool again=FFmpegRuntimeLinker::Init();
  if (again!=actual || attempted.size()!=first_calls)
    return fail(scenario,"memoized original loader retried on a second Init call");
  if (actual!=expect_success)
    return fail(scenario,"original Init result did not match provider scenario");
  const size_t expected_attempts=(
    active==Scenario::FirstSuccess ? 1 :
    active==Scenario::BadThenSuccess ? 2 : 14);
  if (first_calls!=expected_attempts) return fail(scenario,"unexpected NSPR candidate attempts");
  if (FFmpegLibWrapper::link_calls!=want_link_calls ||
      FFmpegLibWrapper::callback_calls!=want_decoder_init ||
      codecs_initialized!=want_decoder_init ||
      encoders_initialized!=want_decoder_init)
    return fail(scenario,"FFmpeg ABI Link/decoder/encoder initialization count mismatch");
  const auto wanted_status=(
    active==Scenario::InvalidPriority
      ? FFmpegRuntimeLinker::LinkStatus_INVALID_FFMPEG_CANDIDATE
      : expect_success ? FFmpegRuntimeLinker::LinkStatus_SUCCEEDED
                       : FFmpegRuntimeLinker::LinkStatus_NOT_FOUND);
  if (status!=wanted_status)
    return fail(scenario,"original FFmpeg preferred error/success status wrong");
  if (active==Scenario::InvalidPriority && status_library!=sLibs[1])
    return fail(scenario,"invalid candidate priority library name wrong");
  if (expect_success && status_library!=attempted.back())
    return fail(scenario,"successful candidate filename not memoized");
  if (!expect_success && active==Scenario::MissingAll && !status_library.empty())
    return fail(scenario,"all-absent candidates must keep empty linked name");
  std::printf(
    "{\"scenario\":\"%s\",\"exact_original_FFmpeg_Init_executed\":true,"
    "\"provider_loader_and_link_ABIs_mocked\":true,"
    "\"original_linux_candidate_count\":14,"
    "\"observed_ns_failed_or_loaded_attempts\":%zu,"
    "\"expected_success\":%s,\"observed_success\":%s,"
    "\"cached_second_Init_avoided_loads\":true,"
    "\"decoded_actual_video_frames\":false,"
    "\"real_FFmpeg_shared_library_loaded\":false,"
    "\"normal_packaged_browser_executed\":false,"
    "\"software_video_fallback_proven\":false}\n",
    scenario,first_calls,expect_success?"true":"false",actual?"true":"false");
  return 0;
}
