/* Disposable native Firefox 160 sandbox actor, never shipped in the browser.
 * Only the isolated CI extraction registers this actor.
 * Source references: security/sandbox/linux/SandboxFilter.cpp and
 * security/sandbox/test/browser_content_sandbox_syscalls.js.
 */
"use strict";
export class VulpraSeccompProbeChild extends JSWindowActorChild {
  receiveMessage(message) {
    const homeWrite = message.name === "VulpraTestDeniedHomeWrite" &&
      message.data?.token === "vulpra160-denied-home-write";
    const prctlProbe = message.name === "VulpraTestBlockedPrctl" &&
      message.data?.token === "vulpra160-prctl-capbset-read";
    if (!homeWrite && !prctlProbe) {
      throw new Error("Unrecognized native sandbox probe");
    }
    const canaryPath = message.data?.canaryPath;
    if (homeWrite) {
      // Accept only this CI-owned home canary, never any ordinary user path.
      if (typeof canaryPath !== "string" || canaryPath.length > 256 ||
          !/^\/tmp\/vulpra160-real-prctl-[^/]+\/home\/vulpra-write-canary$/.test(
            canaryPath)) {
        throw new Error("Refusing non-disposable native file-write target");
      }
    }
    const appinfo = Cc["@mozilla.org/xre/app-info;1"].getService(
      Ci.nsIXULRuntime
    );
    if (appinfo.processType !== Ci.nsIXULRuntime.PROCESS_TYPE_CONTENT) {
      throw new Error("Native probe not in an actual content process");
    }
    const { ctypes } = ChromeUtils.importESModule(
      "resource://gre/modules/ctypes.sys.mjs"
    );
    const libc = ctypes.open("libc.so.6");
    try {
      const prctl = libc.declare("prctl", ctypes.default_abi, ctypes.int,
        ctypes.int, ctypes.unsigned_long, ctypes.unsigned_long,
        ctypes.unsigned_long, ctypes.unsigned_long);
      const modeAtInvocation = prctl(21, 0, 0, 0, 0); // PR_GET_SECCOMP
      if (modeAtInvocation !== 2) {
        throw new Error("Actual content actor has no seccomp filter");
      }
      if (homeWrite) {
        const open = libc.declare("open", ctypes.default_abi, ctypes.int,
          ctypes.char.ptr, ctypes.int, ctypes.unsigned_int);
        const close = libc.declare("close", ctypes.default_abi, ctypes.int,
          ctypes.int);
        const rv = open(canaryPath, 193, 384);
        // Linux O_CREAT|O_EXCL|O_WRONLY, mode 0600
        const errno = ctypes.errno;
        if (rv >= 0) {
          close(rv);
        }
        return {
          observationKind: "native_open_create_home_denial_in_real_content",
          processType: appinfo.processType, processId: appinfo.processID,
          modeAtInvocation, rv, errno
        };
      }
      const rv = prctl(23, 0, 0, 0, 0); // PR_CAPBSET_READ, CAP_CHOWN
      const errno = ctypes.errno;
      return {
        observationKind: "native_prctl_capbset_read_in_real_content",
        processType: appinfo.processType, processId: appinfo.processID,
        modeAtInvocation, rv, errno
      };
    } finally {
      libc.close();
    }
  }
}
