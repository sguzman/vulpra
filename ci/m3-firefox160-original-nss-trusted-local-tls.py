#!/usr/bin/env python3
"""Original Firefox160 real trusted-local HTTPS with a temporary NSS CA only.

Strict public baseline untrusted cert refusal; same local server accepted after
CA is inserted into ONLY a disposable NSS profile, shipped through geckodriver
as a base64 ZIP; missing original NSS providers tested with that same CA ZIP.
No system trust changes, proxy bypass, original profile or raw key export.
"""
from __future__ import annotations
import base64
import contextlib
import hashlib
import http.server
import importlib.util
import io
import json
import os
from pathlib import Path
import signal
import socket
import ssl
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
import zipfile
from threading import Thread

# Reuse exact source-verified native browser, WebDriver response, native
# process-group and NSS shim log parsers already accepted by earlier CI.
import importlib.machinery
previous_path = Path(__file__).with_name("m3-firefox160-browser-nss-local-tls-replay.py")
source = importlib.machinery.SourceFileLoader("_vulpra_original_nss_browser", str(previous_path)).load_module()
request = source.request
error_class = source.error_class
find_port = source.find_port
end_process = source.end_process
denied_counts = source.denied_counts
Page = source.Page

MODES = (("untrusted", None, False),
         ("trusted", None, True),
         ("trusted_softoken_denied", "nss_softoken", True),
         ("trusted_freebl_denied", "nss_freebl", True),
         ("trusted_both_targeted", "nss_both", True))


def run(args, *, timeout=20):
    subprocess.run(args, check=True, timeout=timeout, stdout=subprocess.DEVNULL,
                   stderr=subprocess.DEVNULL)


def build_certificates(tmp):
    # CA and private keys stay ephemeral under the CI runner only.
    ca_key, ca_crt = tmp / "ci-ca-private.key", tmp / "ci-ca-public.crt"
    leaf_key, leaf_csr = tmp / "ci-server-private.key", tmp / "ci-server.csr"
    leaf_crt, ext = tmp / "ci-server.crt", tmp / "ci-server-ext.conf"
    run(["openssl","req","-new","-x509","-nodes","-newkey","rsa:2048",
         "-days","1","-sha256","-subj","/CN=Vulpra-Ephemeral-Test-CA",
         "-addext","basicConstraints=critical,CA:TRUE",
         "-addext","keyUsage=critical,keyCertSign,cRLSign",
         "-keyout",str(ca_key),"-out",str(ca_crt)])
    run(["openssl","req","-new","-nodes","-newkey","rsa:2048",
         "-sha256","-subj","/CN=127.0.0.1",
         "-keyout",str(leaf_key),"-out",str(leaf_csr)])
    ext.write_text("basicConstraints=critical,CA:FALSE\n"
                   "keyUsage=critical,digitalSignature,keyEncipherment\n"
                   "extendedKeyUsage=serverAuth\nsubjectAltName=IP:127.0.0.1\n")
    run(["openssl","x509","-req","-in",str(leaf_csr),"-CA",str(ca_crt),
         "-CAkey",str(ca_key),"-CAcreateserial","-days","1","-sha256",
         "-extfile",str(ext),"-out",str(leaf_crt)])
    return ca_crt, leaf_crt, leaf_key


def disposable_trusted_nss_profile(tmp, ca_cert):
    certdir = tmp / "temporary-test-nss-profile"
    certdir.mkdir(mode=0o700)
    run(["certutil","-N","-d",f"sql:{certdir}","--empty-password"])
    run(["certutil","-A","-d",f"sql:{certdir}","-n",
         "Vulpra localhost-only temporary CI trust anchor",
         "-t","C,,","-i",str(ca_cert)])
    run(["certutil","-L","-d",f"sql:{certdir}","-n",
         "Vulpra localhost-only temporary CI trust anchor"])
    files = [certdir / name for name in ("cert9.db","key4.db","pkcs11.txt")
             if (certdir / name).is_file()]
    if len(files) < 2:
        raise RuntimeError("temporary profile NSS trust database not created")
    checksums = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
    memory = io.BytesIO()
    with zipfile.ZipFile(memory, "w", zipfile.ZIP_DEFLATED) as z:
        for p in files:
            z.write(p, arcname=p.name)
    return base64.b64encode(memory.getvalue()).decode("ascii"), files, checksums


def web_session(mode, denial, profile, browser, shim, gecko, tmp, trusted_url):
    home = tmp / f"{mode}-home"
    home.mkdir(mode=0o700)
    sentinel = home / ".mozilla/firefox/profiles.ini"
    sentinel.parent.mkdir(parents=True)
    sentinel.write_bytes(b"sentinel: original personal Firefox profile must never be used\n")
    initial_hash = hashlib.sha256(sentinel.read_bytes()).hexdigest()
    log = tmp / f"{mode}-private-native-loads.log"
    log.touch(mode=0o600)
    gecko_log = tmp / f"{mode}-private-geckodriver.log"
    env = os.environ.copy()
    for key in ("LD_PRELOAD","VULPRA_M3_DENY_GROUP","VULPRA_M3_DENY_LOG",
                "VULPRA_M3_DENY_FIXTURE_EXE","DISPLAY","WAYLAND_DISPLAY",
                "MOZ_REMOTE"):
        env.pop(key,None)
    env.update({"HOME":str(home),"XDG_DATA_HOME":str(home / ".local/share"),
                "MOZ_HEADLESS":"1","MOZ_CRASHREPORTER_DISABLE":"1",
                "NO_PROXY":"127.0.0.1,localhost",
                "no_proxy":"127.0.0.1,localhost"})
    if denial:
        env.update({"LD_PRELOAD":str(shim),"VULPRA_M3_DENY_GROUP":denial,
                    "VULPRA_M3_DENY_LOG":str(log)})
    port = find_port()
    proc = None
    session = None
    result = {
        "mode":mode,"denial_group":denial or "none",
        "temporary_CA_profile_injected":bool(profile),
        "driver_ready":False,"session_created":False,
        "session_outcome":"not_started","session_error_class":"not_attempted",
        "original_packaged_firefox_reported":False,
        "accept_insecure_certs":None,
        "local_https_outcome":"not_attempted",
        "local_https_error_class":"not_attempted",
        "actual_trusted_https_secure_document_title_and_javascript":False,
        "browser_is_secure_context":False,
        "private_profile_sentinel_preserved":False,
        "native_denied_softoken_loads":0,"native_denied_freebl_loads":0,
        "browser_native_shim_attachment_witness_count":0,
        "unexpected_native_provider_denial_lines":0,
        "raw_log_keys_geckodriver_errors_profile_paths_or_pids_archived":False,
    }
    try:
        with gecko_log.open("wb") as out:
            proc = subprocess.Popen([str(gecko),"--host","127.0.0.1","--port",str(port)],
                                    env=env,stdout=out,stderr=subprocess.STDOUT,
                                    start_new_session=True)
            deadline = time.monotonic()+25
            while time.monotonic()<deadline:
                if proc.poll() is not None:
                    result["session_outcome"]="driver_exited"
                    break
                try:
                    _,status=request(port,"GET","/status",timeout=2)
                    if isinstance(status,dict) and status.get("ready") is True:
                        result["driver_ready"]=True;break
                except (OSError,TimeoutError,ValueError):
                    pass
                time.sleep(0.17)
            if not result["driver_ready"]:
                if result["session_outcome"]=="not_started":
                    result["session_outcome"]="driver_not_ready"
            else:
                fx_options={"binary":str(browser),"args":["-headless","-no-remote"],
                            "prefs":{"browser.shell.checkDefaultBrowser":False,
                                     "app.update.enabled":False,
                                     "extensions.update.enabled":False}}
                if profile:
                    fx_options["profile"]=profile
                caps={"capabilities":{"alwaysMatch":{
                    "browserName":"firefox","acceptInsecureCerts":False,
                    "moz:firefoxOptions":fx_options}}}
                try:
                    code,value=request(port,"POST","/session",caps,timeout=45)
                except (OSError,TimeoutError,ValueError):
                    result["session_outcome"]="session_transport_failure_or_timeout"
                else:
                    if code>=400 or not isinstance(value,dict) or not isinstance(value.get("sessionId"),str):
                        result["session_outcome"]="webdriver_session_rejected"
                        result["session_error_class"]=error_class(value)
                    else:
                        session=value["sessionId"]
                        reported=value.get("capabilities") or {}
                        result["session_created"]=True
                        result["original_packaged_firefox_reported"]=reported.get("browserName")=="firefox"
                        result["accept_insecure_certs"]=reported.get("acceptInsecureCerts")
                        result["session_outcome"]="session_created"
                        base="/session/"+session
                        try:
                            code,value=request(port,"POST",base+"/url",
                                               {"url":trusted_url},timeout=35)
                            if code>=400 or (isinstance(value,dict) and value.get("error")):
                                result["local_https_error_class"]=error_class(value)
                                result["local_https_outcome"]=(
                                    "strict_certificate_rejection"
                                    if error_class(value)=="insecure certificate"
                                    else "webdriver_navigation_failed")
                            else:
                                code,actual=request(port,"POST",base+"/execute/sync",
                                    {"script":
                                      "return {title:document.title,secure:window.isSecureContext,"
                                      "scheme:location.protocol,text:!!document.querySelector('h1')"
                                      "&&document.querySelector('h1').textContent==="
                                      "'Localhost NSS diagnostic fixture',js:7*6===42};",
                                     "args":[]},timeout=14)
                                if code<400 and isinstance(actual,dict):
                                    result["browser_is_secure_context"]=actual.get("secure") is True
                                    result["actual_trusted_https_secure_document_title_and_javascript"]=(
                                        actual.get("title")=="Vulpra NSS localhost test" and
                                        actual.get("scheme")=="https:" and
                                        actual.get("secure") is True and
                                        actual.get("text") is True and
                                        actual.get("js") is True)
                                result["local_https_outcome"]=(
                                    "verified_secure_document_and_javascript"
                                    if result["actual_trusted_https_secure_document_title_and_javascript"]
                                    else "navigation_without_secure_document_proof")
                        except (OSError,TimeoutError,ValueError):
                            result["local_https_outcome"]="navigation_transport_failure_or_timeout"
    finally:
        if session:
            with contextlib.suppress(Exception):
                request(port,"DELETE","/session/"+session,timeout=5)
        end_process(proc)
        result["private_profile_sentinel_preserved"]=(
            sentinel.exists() and hashlib.sha256(sentinel.read_bytes()).hexdigest()==initial_hash)
        counts,attached,unknown=denied_counts(log)
        result["native_denied_softoken_loads"]=counts["libsoftokn3.so"]
        result["native_denied_freebl_loads"]=counts["libfreeblpriv3.so"]
        result["browser_native_shim_attachment_witness_count"]=attached
        result["unexpected_native_provider_denial_lines"]=unknown
    return result


def main():
    if sys.argv[1:]==["--self-test"]:
        assert len(MODES)==5
        assert error_class({"error":"insecure certificate","message":"private content"})=="insecure certificate"
        assert error_class({"error":"/private/error"})=="other_webdriver_error"
        assert MODES[0][2] is False and all(v[2] for v in MODES[1:])
        print("PASS: disposable NSS custom CA and five real browser mode definitions")
        return 0
    if len(sys.argv)!=5:
        raise SystemExit("usage: tls.py APPDIR DENIAL_SHIM_SO GECKODRIVER REPORT_JSON")
    appdir,shim,gecko,output=map(Path,sys.argv[1:])
    if any(not p.is_absolute() for p in (appdir,shim,gecko,output)):
        raise RuntimeError("absolute CI filesystem paths required")
    if output.exists():
        raise RuntimeError("original source-attested TLS result already exists")
    ini=appdir/"application.ini"
    if not ini.is_file() or "Name=Vulpra" not in ini.read_text().splitlines():
        raise RuntimeError("exact original packaged Vulpra application.ini missing")
    browser=None
    for name in ("vulpra","firefox"):
        p=appdir/name
        if p.is_file() and os.access(p,os.X_OK) and p.open("rb").read(4)==b"\x7fELF":
            browser=p;break
    if browser is None or not shim.is_file() or not gecko.is_file():
        raise RuntimeError("real binary, shim and pinned driver must exist")
    for name in ("libnss3.so","libsoftokn3.so","libfreeblpriv3.so","libnspr4.so"):
        p=appdir/name
        if p.is_symlink() or not p.is_file() or p.open("rb").read(4)!=b"\x7fELF":
            raise RuntimeError("expected original NSS ELF not present")
    with tempfile.TemporaryDirectory(dir=os.environ["RUNNER_TEMP"],
                                     prefix="vulpra-trusted-nss-ci-") as directory:
        tmp=Path(directory)
        ca_cert,server_cert,server_key=build_certificates(tmp)
        zipped,dbfiles,dbhashes=disposable_trusted_nss_profile(tmp,ca_cert)
        server=http.server.ThreadingHTTPServer(("127.0.0.1",0),Page)
        server_tls=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        server_tls.load_cert_chain(str(server_cert),str(server_key))
        server.socket=server_tls.wrap_socket(server.socket,server_side=True)
        Thread(target=server.serve_forever,daemon=True).start()
        url=f"https://127.0.0.1:{server.server_port}/page"
        proxy_free=urllib.request.build_opener(urllib.request.ProxyHandler({}))
        trusted=urllib.request.build_opener(
            urllib.request.HTTPSHandler(context=ssl.create_default_context(cafile=str(ca_cert))),
            urllib.request.ProxyHandler({}))
        try:
            with trusted.open(url,timeout=8) as r:
                if r.status!=200 or b"Localhost NSS diagnostic fixture" not in r.read(4096):
                    raise RuntimeError("CA-authenticated HTTPS fixture not healthy")
            try:
                proxy_free.open(url,timeout=8)
            except urllib.error.URLError as err:
                if not isinstance(err.reason,ssl.SSLCertVerificationError):
                    raise RuntimeError("default host TLS client failed for wrong reason") from None
            else:
                raise RuntimeError("localhost CI CA unexpectedly trusted by system")
            results=[web_session(mode,denial,zipped if trusted_ca else None,browser,
                                 shim,gecko,tmp,url) for mode,denial,trusted_ca in MODES]
        finally:
            server.shutdown()
            server.server_close()
        db_unchanged=all(p.exists() and hashlib.sha256(p.read_bytes()).hexdigest()==dbhashes[p.name]
                         for p in dbfiles)
    denied=results[2:]
    report={
      "schema_version":1,
      "status":"firefox160_original_actual_trusted_disposable_NSS_CA_local_HTTPS_browser_and_denial",
      "original_official_firefox160_commit":"2887d9de1f69c0e9776413da80e7ba0d1225dd9b",
      "original_vulpra_28_overlay_source_tree":"42dd7439a27dde92f89ac5eed13f88117a4d7ab5",
      "original_compiled_browser_archive_sha256":"530b79584801c3632a583d4ebca7e4f5158870133f88dae647d5be7b7def97eb",
      "original_native_producer_run":43138458940,
      "test_harness_commit":os.environ["GITHUB_SHA"],
      "real_original_Firefox160_native_elf_used":True,
      "actual_localhost_TLS_server_with_ephemeral_CA_verified_by_host":True,
      "ephemeral_local_CA_not_trusted_by_default_system_client":True,
      "temporary_NSS_cert9_key4_database_profile_only":True,
      "temporary_NSS_database_bytes_unchanged":db_unchanged,
      "temporary_CA_profile_encoded_as_geckodriver_base64_ZIP":True,
      "acceptInsecureCerts_never_enabled":True,
      "untrusted_original_browser_rejected_same_local_https_server":(
          results[0]["session_created"] and
          results[0]["local_https_outcome"]=="strict_certificate_rejection" and
          results[0]["accept_insecure_certs"] is False),
      "trusted_original_browser_verified_actual_secure_https_document_and_JS":(
          results[1]["session_created"] and
          results[1]["actual_trusted_https_secure_document_title_and_javascript"] and
          results[1]["browser_is_secure_context"] and
          results[1]["accept_insecure_certs"] is False),
      "denied_softoken_actual_named_request_seen":(
          results[2]["native_denied_softoken_loads"]>0 and
          results[2]["browser_native_shim_attachment_witness_count"]>0),
      "denied_freebl_actual_named_request_seen":(
          results[3]["native_denied_freebl_loads"]>0 and
          results[3]["browser_native_shim_attachment_witness_count"]>0),
      "all_disposable_profile_sentinels_preserved":all(
          r["private_profile_sentinel_preserved"] for r in results),
      "all_denied_modes_reached_successful_trusted_HTTPS":all(
          r["actual_trusted_https_secure_document_title_and_javascript"] for r in denied),
      "trusted_TLS_success_in_denied_provider_modes_proven":False,
      "real_external_TLS_or_public_sites_tested":False,
      "all_NSS_FIPS_PKCS11_browser_security_paths_proven":False,
      "system_NSS_trust_store_or_user_profiles_modified":False,
      "raw_CA_keys_geckodriver_logs_paths_PIDs_profiles_archived":False,
      "direct_compiled_NSS_dlopen_callsite_or_full_Rust_CXX_FFI_proven":False,
      "source_pruning_authorized":False,"security_current":False,
      "release_ready":False,"m3_sixth_gate_closed":False,
      "modes":results,
    }
    output.write_text(json.dumps(report,sort_keys=True,indent=2)+"\n")
    for m in results:
        print("AUDIT: trusted-local-NSS mode="+m["mode"]+
              " session="+str(m["session_created"]).lower()+
              " tls="+m["local_https_outcome"]+
              " softoken_denied="+str(m["native_denied_softoken_loads"])+
              " freebl_denied="+str(m["native_denied_freebl_loads"]))
    if not report["untrusted_original_browser_rejected_same_local_https_server"]:
        raise RuntimeError("untrusted baseline unexpectedly accepted local CA or failed startup")
    if not report["trusted_original_browser_verified_actual_secure_https_document_and_JS"]:
        raise RuntimeError("original packaged Firefox did not complete CA-authenticated trusted HTTPS")
    if not report["all_disposable_profile_sentinels_preserved"] or not db_unchanged:
        raise RuntimeError("temporary cert database or private profile sentinel modified")
    if not report["denied_softoken_actual_named_request_seen"] or not report["denied_freebl_actual_named_request_seen"]:
        raise RuntimeError("one requested provider denial was not actually observed")
    if any(r["local_https_outcome"]=="verified_secure_document_and_javascript" for r in denied):
        raise RuntimeError("trusted HTTPS unexpectedly succeeded under denied cryptographic provider")
    print("PASS: original Firefox160 actual trusted localhost HTTPS with disposable NSS CA and strict untrusted control")
    print("LIMIT: scoped localhost RSA certificate/test CA; not public HTTPS or full NSS FIPS/FFI gate")
    return 0

if __name__=="__main__":
    raise SystemExit(main())
