#!/usr/bin/env python3
"""Receives the DevLog records a `./deploy --devlog` build of Elisa aprende música sends.

A phone cannot write to this Mac's disk, so the instrumented app POSTs batches
of JSON records to /api/devlog and this server appends them, one per line, to
log/devlog.jsonl, echoing each to stdout so a run can be watched live. Files
sent with DevLog.upload arrive at /api/devlog/screen?name=... and land in
log/screens/. Both are emptied on start, so they only hold the current run.

    scripts/devlog/server.py                                   # 0.0.0.0:19482
    ELISA_MUSICA_DEVLOG_PORT=19500 scripts/devlog/server.py
    curl http://$(scutil --get LocalHostName).local:19482/api/devlog/health

Stdlib only. It listens on the LAN without auth, so it caps request, file and
directory sizes instead of trusting the client.
"""

import json
import os
import re
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from threading import Lock
from urllib.parse import parse_qs, urlparse

# Each app has its own DevLog port (vvterm 19480, Japanese Walking 19481, Elisa 19482).
PORT = int(os.getenv("ELISA_MUSICA_DEVLOG_PORT", "19482"))
LOG_DIR = Path(__file__).resolve().parents[2] / "log"
LOG_PATH = LOG_DIR / "devlog.jsonl"
SCREENS_DIR = LOG_DIR / "screens"
MAX_REQUEST_BYTES = 1024 * 1024
MAX_RECORDS_PER_REQUEST = 2000
# At the cap the file rolls to devlog.jsonl.1, so at most two generations exist.
MAX_LOG_BYTES = 32 * 1024 * 1024
MAX_SCREEN_BYTES = 8 * 1024 * 1024
MAX_SCREENS_BYTES = 256 * 1024 * 1024
SCREEN_NAME = re.compile(r"^[A-Za-z0-9._+-]{1,128}$")

write_lock = Lock()


def append(records):
    lines = []
    for record in records:
        try:
            lines.append(json.dumps(record, ensure_ascii=True, separators=(",", ":")))
        except (TypeError, ValueError):
            continue
    if not lines:
        return
    with write_lock:
        if LOG_PATH.exists() and LOG_PATH.stat().st_size >= MAX_LOG_BYTES:
            os.replace(LOG_PATH, LOG_PATH.with_suffix(LOG_PATH.suffix + ".1"))
        with LOG_PATH.open("a", encoding="utf-8") as handle:
            handle.write("\n".join(lines) + "\n")
    for line in lines:
        print(line, flush=True)


def save_screen(name, data):
    if not SCREEN_NAME.match(name) or name.startswith("."):
        return False
    with write_lock:
        used = sum(p.stat().st_size for p in SCREENS_DIR.iterdir() if p.is_file())
        if used + len(data) > MAX_SCREENS_BYTES:
            return False
        (SCREENS_DIR / name).write_bytes(data)
    return True


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if urlparse(self.path).path == "/api/devlog/health":
            self._reply(200, b"ok\n")
        else:
            self._reply(404, b"not found\n")

    def do_POST(self):
        url = urlparse(self.path)
        if url.path == "/api/devlog/screen":
            return self._screen(parse_qs(url.query).get("name", [""])[0])
        if url.path != "/api/devlog":
            return self._reply(404, b"not found\n")
        length = self._length()
        if length <= 0 or length > MAX_REQUEST_BYTES:
            return self._reply(413, b"bad size\n")
        try:
            records = json.loads(self.rfile.read(length))["records"]
            if not isinstance(records, list) or len(records) > MAX_RECORDS_PER_REQUEST:
                raise ValueError("records")
        except (ValueError, KeyError, TypeError):
            return self._reply(400, b"bad payload\n")
        append([r for r in records if isinstance(r, dict)])
        self._reply(204, b"")

    def _screen(self, name):
        length = self._length()
        if length <= 0 or length > MAX_SCREEN_BYTES:
            return self._reply(413, b"bad size\n")
        data = self.rfile.read(length)
        if not save_screen(name, data):
            return self._reply(400, b"bad name or screens full\n")
        print(json.dumps({"kind": "screen.file", "name": name, "bytes": length}), flush=True)
        self._reply(204, b"")

    def _length(self):
        try:
            return int(self.headers.get("Content-Length") or 0)
        except ValueError:
            return -1

    def _reply(self, status, body):
        self.send_response(status)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if body:
            self.wfile.write(body)

    def log_message(self, *args):
        # Records already go to stdout; access lines would bury them.
        pass


def main():
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    LOG_PATH.write_text("")
    LOG_PATH.with_suffix(LOG_PATH.suffix + ".1").unlink(missing_ok=True)
    SCREENS_DIR.mkdir(parents=True, exist_ok=True)
    for old in SCREENS_DIR.iterdir():
        if old.is_file():
            old.unlink()
    server = ThreadingHTTPServer(("0.0.0.0", PORT), Handler)
    print(f"devlog: listening on :{PORT}, writing {LOG_PATH}", file=sys.stderr, flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
