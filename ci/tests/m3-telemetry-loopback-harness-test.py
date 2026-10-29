#!/usr/bin/env python3
"""Offline localhost receiver and fail-closed runtime report fixtures.

Does NOT claim a packaged browser ran; see ci/smoke-telemetry-loopback-package.py.
"""
from __future__ import annotations

from copy import deepcopy
import importlib.util
from pathlib import Path
import socket
import urllib.error
import urllib.request


ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location(
    "vulpra_telemetry_loopback", ROOT / "smoke-telemetry-loopback-package.py")
probe = importlib.util.module_from_spec(spec)
spec.loader.exec_module(probe)


def must_fail(callback):
    try:
        callback()
    except (ValueError, RuntimeError):
        return
    raise AssertionError("Invalid telemetry evidence incorrectly accepted")


def main():
    assert probe.kind("/submit/telemetry/id/deletion-request/app?v=4") == "deletion-request"
    assert probe.kind("/submit/telemetry/id/vulpra-probe/app?v=4") == "vulpra-probe"
    assert probe.kind("/submit/telemetry/id/other?v=4&deletion-request=yes") == "other"
    with probe.sink() as server:
        base = f"http://127.0.0.1:{server.server_port}"
        for kind in ("vulpra-probe", "deletion-request", "unrelated"):
            with urllib.request.urlopen(urllib.request.Request(
                base + f"/submit/telemetry/throwaway/{kind}/app",
                data=b"discard-this-payload"), timeout=5) as resp:
                assert resp.status == 200
        assert probe.counts(server) == {
            "vulpra-probe":1, "deletion-request":1, "other":1}
        assert all(type(x) is str for x in server.requests)
        assert b"discard-this-payload" not in repr(server.requests).encode()
        try:
            urllib.request.urlopen(base + "/not-allowed", timeout=3)
        except urllib.error.HTTPError as exc:
            assert exc.code == 405
        else:
            raise AssertionError("Unexpected GET request accepted")
        with socket.create_connection(("127.0.0.1", server.server_port), timeout=5) as sock:
            sock.sendall(("POST /submit/telemetry/id/vulpra-probe HTTP/1.1\r\n"
                "Host: 127.0.0.1\r\nContent-Length: " +
                str(probe.LIMIT + 1) + "\r\n\r\n").encode())
            assert b" 413 " in sock.recv(1024)
        assert probe.counts(server)["vulpra-probe"] == 1
        with socket.create_connection(("127.0.0.1", server.server_port), timeout=5) as sock:
            sock.sendall(
                b"POST /submit/telemetry/throwaway/vulpra-probe/app HTTP/1.1\r\n"
                b"Host: 127.0.0.1\r\n"
                b"Transfer-Encoding: chunked\r\n"
                b"Connection: close\r\n\r\n"
                b"3\r\nabc\r\n0\r\n\r\n"
            )
            assert b" 200 " in sock.recv(1024)
        assert probe.counts(server)["vulpra-probe"] == 2
        assert probe.rejected_counts(server) == {
            "oversize":1, "bad_framing":0, "truncated":0}
    print("PASS: localhost-only request types, bounded fixed/chunked bodies and redaction")

    record = {"status":"observed", "observer_seen":True, "test_override":True,
        "before":{"ordinary":True, "deletion":True, "policy":True,
                  "sender_ready":True, "server_matches_loopback":True},
        "disabled":{"ordinary":False, "deletion":True, "policy":True},
        "master_off":{"ordinary":False, "deletion":True, "policy":False}}
    full = {"vulpra-probe":1, "deletion-request":0, "other":0}
    probe.validate(record, full, full, {"oversize":0,"bad_framing":0,"truncated":0})
    mutations = (
        lambda r,a,b: r["disabled"].update(ordinary=True),
        lambda r,a,b: r["disabled"].update(deletion=False),
        lambda r,a,b: r["master_off"].update(policy=True),
        lambda r,a,b: r.update(observer_seen=False),
        lambda r,a,b: r.update(test_override=False),
        lambda r,a,b: r["before"].update(ordinary="true"),
        lambda r,a,b: a.update({"vulpra-probe":0}),
        lambda r,a,b: b.update({"vulpra-probe":2}),
        lambda r,a,b: r.update(status="mocked"),
        lambda r,a,b: r["before"].update(sender_ready=False),
        lambda r,a,b: r["before"].update(server_matches_loopback=False),
    )
    for mutation in mutations:
        copy, before, after = deepcopy(record), dict(full), dict(full)
        mutation(copy, before, after)
        must_fail(lambda: probe.validate(copy, before, after))
    print(f"PASS: {len(mutations)} invalid observer, sender, capture and master-policy fixtures rejected")
    must_fail(lambda: probe.validate(record, full, full,
        {"oversize":1, "bad_framing":0, "truncated":0}))
    print("PASS: rejected local HTTP receiver body-size/framing failure evidence")
    print("MOCK ONLY: live Vulpra/WebDriver and remote deletion delivery untested")


if __name__ == "__main__":
    main()
