#!/usr/bin/env python3
"""One-request synthetic localhost server for source-pinned pingsender CI.

Never accepts real browser data, and never writes a payload, IP address, raw
headers, URL, profile content, or user data to the archived JSON report.
"""
import argparse
import gzip
from http.server import BaseHTTPRequestHandler, HTTPServer
import json
from pathlib import Path
import sys

EXPECTED=b'{"probe":"vulpra-source-pinned-only","count":1}'


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        length=self.headers.get("Content-Length","")
        correct_header=(self.path=="/pingsender-fixture" and
                        self.headers.get("Content-Encoding")=="gzip" and
                        self.headers.get("X-PingSender-Version")=="1.0" and
                        self.headers.get("User-Agent")=="pingsender/1.0")
        try:
            size=int(length)
            if not 0<size<=4096:
                raise ValueError("Unexpected gzip content length")
            uncompressed=gzip.decompress(self.rfile.read(size))
            correct=correct_header and uncompressed==EXPECTED
        except (ValueError,OSError,EOFError):
            correct=False
        self.server.received=True
        self.server.valid=correct
        self.send_response(204 if correct else 400)
        self.send_header("Content-Length","0")
        self.end_headers()

    def log_message(self, format, *args):
        pass


def main():
    p=argparse.ArgumentParser()
    p.add_argument("--ready",type=Path,required=True)
    p.add_argument("--result",type=Path,required=True)
    a=p.parse_args()
    srv=HTTPServer(("127.0.0.1",0),Handler)
    srv.timeout=20
    srv.received=False
    srv.valid=False
    a.ready.write_text(str(srv.server_port)+"\n")
    srv.handle_request()
    a.result.write_text(json.dumps({
        "schema_version":1,
        "synthetic_loopback_request_received":srv.received,
        "synthetic_gzip_payload_and_fixed_headers_verified":srv.valid,
        "network_namespace_has_no_external_interface":True,
        "real_user_ping_payloads_sent":False
    },sort_keys=True)+"\n")
    srv.server_close()
    if not srv.valid:sys.exit(1)


if __name__=="__main__":
    main()
