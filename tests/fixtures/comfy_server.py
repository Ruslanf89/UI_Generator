#!/usr/bin/env python3
"""Local HTTP fixture for UI Forge's ComfyUI integration tests.

This deliberately generates simple geometric PNG fixtures, not AI artwork. It
does not download models, run inference, or use a GPU. Bind only to loopback.
"""

import argparse
import json
import struct
import threading
import time
import urllib.parse
import zlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


def png_fixture(width, height, seed, blank=False):
    """Opaque magenta background plus a seeded, clearly synthetic test motif."""
    width, height = max(32, min(int(width), 1024)), max(32, min(int(height), 1024))
    background = bytes((255, 0, 255, 255))
    border = bytes((226, 170 + seed % 50, 48, 255))
    surface = bytes((62 + seed % 80, 48, 26 + seed % 50, 255))
    marker = bytes((45, 100 + seed % 120, 80, 255))
    pad, trim = max(4, width // 12), max(3, width // 40)
    rows = []
    for y in range(height):
        if blank or y < pad or y >= height - pad:
            row = background * width
        elif y < pad + trim or y >= height - pad - trim:
            row = background * pad + border * (width - 2 * pad) + background * pad
        else:
            inner = surface * (width - 2 * pad - 2 * trim)
            if height // 3 <= y < height * 2 // 3:
                length = len(inner) // 4
                middle = max(2, length // 5)
                left = (length - middle) // 2
                inner = surface * left + marker * middle + surface * (length - left - middle)
            row = background * pad + border * trim + inner + border * trim + background * pad
        rows.append(b"\0" + row)

    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(b"".join(rows))) + chunk(b"IEND", b"")


class FixtureState:
    def __init__(self, log):
        self.lock = threading.Lock()
        self.log = log
        self.options = {}
        self.jobs = {}
        self.sequence = 0

    def record(self, method, path, body=None):
        with self.lock:
            with self.log.open("a", encoding="utf-8") as stream:
                stream.write(json.dumps({"method": method, "path": path, "body": body}) + "\n")


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *args):
        pass

    def reply(self, value, status=200, content_type="application/json"):
        data = json.dumps(value).encode() if content_type == "application/json" else value
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Connection", "close")
        self.end_headers()
        try:
            self.wfile.write(data)
        except (BrokenPipeError, ConnectionResetError):
            pass  # A client cancellation is an expected test case.

    @property
    def fixture(self):
        return self.server.fixture

    def do_GET(self):
        parsed = urllib.parse.urlsplit(self.path)
        self.fixture.record("GET", self.path)
        options = self.fixture.options.copy()
        if parsed.path == options.get("delay_path"):
            time.sleep(min(2.0, float(options.get("delay_seconds", 1.0))))
        if parsed.path == "/object_info/CheckpointLoaderSimple":
            if options.get("probe_redirect"):
                self.send_response(302)
                self.send_header("Location", "http://example.invalid/should-never-be-requested")
                self.send_header("Content-Length", "0")
                self.send_header("Connection", "close")
                self.end_headers()
            elif options.get("probe_error"):
                self.reply({"error": "Fixture model discovery unavailable"}, 503)
            elif options.get("probe_bad_json"):
                self.reply(b"not json", content_type="text/plain")
            else:
                checkpoints = [] if options.get("empty_models") else ["fixture.safetensors"]
                self.reply({"CheckpointLoaderSimple": {"input": {"required": {"ckpt_name": [checkpoints]}}}})
        elif parsed.path.startswith("/history/"):
            prompt_id = parsed.path.rsplit("/", 1)[1]
            job = self.fixture.jobs.get(prompt_id)
            if job is None:
                self.reply({})
                return
            job["polls"] += 1
            if options.get("history_bad_json"):
                self.reply(b"invalid history", content_type="text/plain")
            elif options.get("history_wait") or job["polls"] <= int(options.get("wait_polls", 0)):
                self.reply({})
            elif options.get("history_error"):
                self.reply({prompt_id: {"outputs": {}, "status": {"status_str": "error", "completed": False, "messages": [["execution_error", {"node_type": "KSampler", "exception_message": "Fixture sampler failure"}]]}}})
            else:
                images = [] if options.get("empty_output") else [{"filename": prompt_id + ".png", "subfolder": "", "type": "output"}]
                self.reply({prompt_id: {"outputs": {"9": {"images": images}}, "status": {"status_str": "success", "completed": True, "messages": []}}})
        elif parsed.path == "/view":
            filename = urllib.parse.parse_qs(parsed.query).get("filename", [""])[0]
            job = self.fixture.jobs.get(filename.removesuffix(".png"))
            if job is None:
                self.reply({"error": "Unknown fixture image"}, 404)
                return
            if options.get("bad_image") or job["number"] == int(options.get("corrupt_on_job", -1)):
                self.reply(b"This is not PNG image data", content_type="image/png")
            elif options.get("blank_image"):
                self.reply(png_fixture(512, 512, 0, blank=True), content_type="image/png")
            else:
                inputs = job["workflow"]["5"]["inputs"]
                seed = int(job["workflow"]["3"]["inputs"]["seed"])
                self.reply(png_fixture(inputs["width"], inputs["height"], seed), content_type="image/png")
        else:
            self.reply({"error": "Unknown fixture route"}, 404)

    def do_POST(self):
        try:
            length = int(self.headers.get("Content-Length", "0"))
            payload = json.loads(self.rfile.read(length))
        except (ValueError, json.JSONDecodeError):
            self.reply({"error": "Invalid JSON"}, 400)
            return
        self.fixture.record("POST", self.path, payload)
        if self.path == "/__control":
            self.fixture.options = payload.copy()
            if payload.get("reset_jobs"):
                self.fixture.jobs.clear()
                self.fixture.sequence = 0
            self.reply({"ok": True})
            return
        if self.path != "/prompt":
            self.reply({"error": "The client must never mutate the shared server queue"}, 405)
            return
        if self.fixture.options.get("prompt_error"):
            self.reply({"error": {"message": "Fixture prompt rejected"}}, 400)
            return
        workflow = payload.get("prompt", {})
        try:
            inputs = workflow["5"]["inputs"]
            assert inputs["batch_size"] == 1
            assert 64 <= inputs["width"] <= 1024 and 64 <= inputs["height"] <= 1024
            assert inputs["width"] % 8 == 0 and inputs["height"] % 8 == 0
            assert workflow["4"]["inputs"]["ckpt_name"] == "fixture.safetensors"
            assert workflow["3"]["class_type"] == "KSampler"
        except (KeyError, TypeError, AssertionError):
            self.reply({"error": {"message": "Invalid standard fixture workflow"}}, 400)
            return
        self.fixture.sequence += 1
        prompt_id = "fixture_%d" % self.fixture.sequence
        self.fixture.jobs[prompt_id] = {"workflow": workflow, "polls": 0, "number": self.fixture.sequence}
        self.reply({"prompt_id": prompt_id, "number": self.fixture.sequence, "node_errors": {}})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port-file", required=True)
    parser.add_argument("--log-file", required=True)
    args = parser.parse_args()
    state = FixtureState(Path(args.log_file))
    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    server.daemon_threads = True
    server.fixture = state
    Path(args.port_file).write_text(str(server.server_port), encoding="utf-8")
    server.serve_forever(poll_interval=0.1)


if __name__ == "__main__":
    main()
