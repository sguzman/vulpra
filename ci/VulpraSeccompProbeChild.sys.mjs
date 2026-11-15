/* Dedicated disposable Firefox 160 native sandbox probe.
 * This module must only be loaded into a temporary native CI extraction.
 * Upstream kernel policy: SandboxFilter.cpp -> PrctlPolicy ->
 * PR_CAPBSET_READ returns Error(EINVAL) after the sandbox is installed.
 */
"use strict";
export class VulpraSeccompProbeChild extends JSWindowActorChild {
  receiveMessage(message) {
    if (message.name !== "VulpraTestBlockedPrctl" ||
        message.data?.token !== "vulpra160-prctl-capbset-read") {
      throw new Error("Unrecognized sandbox test request");
    }
    const appinfo = Cc["@mozilla.org/xre/app-info;1"].getService(
      Ci.nsIXULRuntime
    );
    if (appinfo.processType !== Ci.nsIXULRuntime.PROCESS_TYPE_CONTENT) {
      throw new Error("Syscall probe was not inside an actual content process");
    }
    // The only writable target probed is a canary under the CI-only HOME.
    // Do not accept arbitrary native file paths from an actor message.
    const canary = message.data?.canaryPath;
    if (typeof canary !== "string" || canary.length > 256 ||
        !canary.startsWith("/tmp/vulpra160-real-prctl-") ||
        !canary.endsWith("/home/vulpra-home-write-canary") ||
        canary.includes("/../")) {
      throw new Error("Refusing any non-disposable HOME write probe");
    }
    const { ctypes } = ChromeUtils.importESModule(
      "resource://gre/modules/ctypes.sys.mjs"
    );
    const libc = ctypes.open("libc.so.6");
    try {
      const prctl = libc.declare("prctl", ctypes.default_abi, ctypes.int,
        ctypes.int, ctypes.unsigned_long, ctypes.unsigned_long,
        ctypes.unsigned_long, ctypes.unsigned_long);
      // Same thread, immediately before the denied operation:
      // PR_GET_SECCOMP is source-allowed by Mozilla's PrctlPolicy.
      const modeAtInvocation = prctl(21, 0, 0, 0, 0);
      if (modeAtInvocation !== 2) {
        throw new Error("Native content actor has no active seccomp filter");
      }
      const rv = prctl(23, 0, 0, 0, 0); // PR_CAPBSET_READ, CAP_CHOWN
      const errno = ctypes.errno;
      // Separate sandbox filesystem policy: upstream Mozilla content tests
      // require open(O_CREAT|O_WRONLY) under HOME to fail. The exact same
      // disposable canary is first opened successfully by the browser parent.
      const open = libc.declare("open", ctypes.default_abi, ctypes.int,
        ctypes.char.ptr, ctypes.int, ctypes.unsigned_int);
      const homeWriteRv = open(canary, 65, 0o600); // Linux O_CREAT|O_WRONLY
      const homeWriteErrno = ctypes.errno;
      if (homeWriteRv >= 0) {
        const close = libc.declare("close", ctypes.default_abi,
          ctypes.int, ctypes.int);
        close(homeWriteRv);
      }
      return {
        observationKind: "native_prctl_capbset_read_in_real_content",
        processType: appinfo.processType,
        processId: appinfo.processID,
        modeAtInvocation, rv, errno, homeWriteRv, homeWriteErrno
      };
    } finally {
      libc.close();
    }
  }
}
