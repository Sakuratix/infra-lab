import json
import sys
import threading
import urllib.error
import urllib.request
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import app


@pytest.fixture(scope="module")
def base_url():
    server = app.make_server(host="127.0.0.1", port=0)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    yield f"http://127.0.0.1:{server.server_port}"
    server.shutdown()


def get(url):
    try:
        with urllib.request.urlopen(url, timeout=5) as r:
            return r.status, r.read().decode()
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()


def test_root(base_url):
    status, body = get(base_url + "/")
    assert status == 200
    assert json.loads(body)["service"] == "infra-lab"


def test_health_and_ready(base_url):
    assert get(base_url + "/healthz")[0] == 200
    assert get(base_url + "/readyz")[0] == 200


def test_not_found(base_url):
    assert get(base_url + "/nope")[0] == 404


def test_metrics_count_requests(base_url):
    get(base_url + "/")
    status, body = get(base_url + "/metrics")
    assert status == 200
    assert 'http_requests_total{method="GET",path="/",status="200"}' in body
    assert "http_request_duration_seconds_count" in body
