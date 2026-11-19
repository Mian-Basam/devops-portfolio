#!/usr/bin/env python3
"""Tiny dependency-free web service used to demonstrate deployments.

GET /        -> JSON with host + version (shows which server answered)
GET /health  -> 200 "ok" while the app is healthy, 503 while draining
"""
import json
import os
import signal
import socket
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

VERSION = os.environ.get("APP_VERSION", "dev")
PORT = int(os.environ.get("APP_PORT", "8000"))
ENV = os.environ.get("APP_ENV", "lab")
DRAIN_FILE = os.environ.get("DRAIN_FILE", "/run/hello-dc/drain")


class Handler(BaseHTTPRequestHandler):
    server_version = f"hello-dc/{VERSION}"

    def _send(self, code, body, ctype="application/json"):
        data = body.encode()
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):  # noqa: N802 (stdlib naming)
        if self.path == "/health":
            if os.path.exists(DRAIN_FILE):
                return self._send(503, "draining\n", "text/plain")
            return self._send(200, "ok\n", "text/plain")
        if self.path == "/":
            return self._send(200, json.dumps(
                {"host": socket.gethostname(), "version": VERSION, "env": ENV}) + "\n")
        return self._send(404, json.dumps({"error": "not found"}) + "\n")

    def log_message(self, fmt, *args):
        print(f'{self.address_string()} "{fmt % args}"', flush=True)


def main():
    httpd = ThreadingHTTPServer(("0.0.0.0", PORT), Handler)
    # shutdown() blocks until serve_forever() returns, so it must run in another
    # thread; calling it directly from the signal handler would deadlock.
    def _on_sigterm(*_):
        threading.Thread(target=httpd.shutdown).start()

    signal.signal(signal.SIGTERM, _on_sigterm)
    print(f"hello-dc {VERSION} listening on :{PORT}", flush=True)
    httpd.serve_forever()
    httpd.server_close()
    print("hello-dc stopped cleanly", flush=True)


if __name__ == "__main__":
    main()
