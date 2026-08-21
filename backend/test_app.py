import pytest

from app import app, state


@pytest.fixture
def client():
    app.config.update(TESTING=True)
    state["healthy"] = True
    state["served"] = 0
    with app.test_client() as test_client:
        yield test_client


def test_the_page_says_which_node_served_it(client):
    response = client.get("/")

    assert response.status_code == 200
    assert b"web1" in response.data or b"container" in response.data


def test_whoami_reports_the_node_and_the_counter(client):
    first = client.get("/api/whoami").get_json()
    second = client.get("/api/whoami").get_json()

    assert first["healthy"] is True
    assert second["served"] == first["served"] + 1
    assert "container" in second
    assert second["uptime"] >= 0


def test_the_forwarded_header_is_passed_through(client):
    response = client.get("/api/whoami", headers={"X-Forwarded-For": "203.0.113.9"})

    assert response.get_json()["forwarded_for"] == "203.0.113.9"


def test_a_healthy_node_answers_the_health_check_with_200(client):
    response = client.get("/healthz")

    assert response.status_code == 200
    assert response.data == b"ok"


def test_draining_makes_the_health_check_fail_without_stopping_the_app(client):
    client.post("/admin/health/down")

    assert client.get("/healthz").status_code == 503
    assert client.get("/api/whoami").status_code == 200
    assert client.get("/api/whoami").get_json()["healthy"] is False


def test_a_drained_node_can_be_put_back(client):
    client.post("/admin/health/down")
    client.post("/admin/health/up")

    assert client.get("/healthz").status_code == 200


def test_an_unknown_health_mode_is_rejected(client):
    response = client.post("/admin/health/sideways")

    assert response.status_code == 400
    assert "up or down" in response.get_json()["error"]


def test_the_health_toggle_reports_the_new_state(client):
    payload = client.post("/admin/health/down").get_json()

    assert payload["healthy"] is False
    assert "node" in payload


def test_the_landing_page_and_the_api_share_the_request_counter(client):
    client.get("/")
    client.get("/")

    assert client.get("/api/whoami").get_json()["served"] == 3


def test_the_health_check_does_not_inflate_the_counter(client):
    client.get("/healthz")
    client.get("/healthz")

    assert client.get("/api/whoami").get_json()["served"] == 1
