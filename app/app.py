"""Tiny HTTP service with health checks and Prometheus metrics.

Stdlib only, so the image stays small and there is nothing to patch
except Python itself.
"""

import json
import os
import signal
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

VERSION = os.getenv("APP_VERSION", "dev")
BUCKETS = (0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0)

_lock = threading.Lock()
_requests: dict[tuple[str, str, int], int] = {}
_latency = {"count": 0, "sum": 0.0, "buckets": [0] * len(BUCKETS)}
_ready = threading.Event()


def observe(method: str, path: str, status: int, seconds: float) -> None:
    with _lock:
        key = (method, path, status)
        _requests[key] = _requests.get(key, 0) + 1
        _latency["count"] += 1
        _latency["sum"] += seconds
        for i, b in enumerate(BUCKETS):
            if seconds <= b:
                _latency["buckets"][i] += 1


def render_metrics() -> str:
    lines = [
        "# HELP app_info Build information.",
        "# TYPE app_info gauge",
        f'app_info{{version="{VERSION}"}} 1',
        "# HELP http_requests_total Total HTTP requests.",
        "# TYPE http_requests_total counter",
    ]
    with _lock:
        for (m, p, s), n in sorted(_requests.items()):
            lines.append(f'http_requests_total{{method="{m}",path="{p}",status="{s}"}} {n}')
        lines += [
            "# HELP http_request_duration_seconds Request latency.",
            "# TYPE http_request_duration_seconds histogram",
        ]
        for b, n in zip(BUCKETS, _latency["buckets"], strict=True):
            lines.append(f'http_request_duration_seconds_bucket{{le="{b}"}} {n}')
        lines.append(f'http_request_duration_seconds_bucket{{le="+Inf"}} {_latency["count"]}')
        lines.append(f"http_request_duration_seconds_sum {_latency['sum']:.6f}")
        lines.append(f"http_request_duration_seconds_count {_latency['count']}")
    return "\n".join(lines) + "\n"


class Handler(BaseHTTPRequestHandler):
    server_version = "infra-lab"

    def _send(self, status: int, body: str, ctype: str = "application/json") -> None:
        data = body.encode()
        self.send_response(status)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self) -> None:
        start = time.perf_counter()
        path = self.path.split("?", 1)[0]
        if path == "/":
            status, body = 200, json.dumps({"service": "infra-lab", "version": VERSION})
            self._send(status, body)
        elif path == "/healthz":
            status = 200
            self._send(status, '{"status":"ok"}')
        elif path == "/readyz":
            status = 200 if _ready.is_set() else 503
            self._send(status, json.dumps({"ready": _ready.is_set()}))
        elif path == "/metrics":
            status = 200
            self._send(status, render_metrics(), "text/plain; version=0.0.4")
        else:
            status, path = 404, "other"
            self._send(status, '{"error":"not found"}')
        observe("GET", path, status, time.perf_counter() - start)

    def log_message(self, fmt: str, *args) -> None:
        print(
            json.dumps({"ts": time.time(), "client": self.client_address[0], "msg": fmt % args}), flush=True
        )


def make_server(host: str = "0.0.0.0", port: int = 8080) -> ThreadingHTTPServer:
    server = ThreadingHTTPServer((host, port), Handler)
    _ready.set()
    return server


def main() -> None:
    server = make_server(port=int(os.getenv("PORT", "8080")))

    def shutdown(*_):
        _ready.clear()  # stop receiving traffic first, then exit
        threading.Thread(target=server.shutdown).start()

    signal.signal(signal.SIGTERM, shutdown)
    print(f"listening on :{server.server_port}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
