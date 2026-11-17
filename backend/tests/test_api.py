from datetime import datetime, timedelta, timezone

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, select
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app import models
from app.config import settings
from app.database import Base, get_db
from app.main import app, limiter


@pytest.fixture
def client(monkeypatch):
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    testing_session = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)
    Base.metadata.create_all(engine)

    def override_get_db():
        db = testing_session()
        try:
            yield db
        finally:
            db.close()

    monkeypatch.setattr(settings, "jwt_secret", "test-only-signing-key-that-is-never-deployed")
    limiter.enabled = False
    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as test_client:
        yield test_client, testing_session
    app.dependency_overrides.clear()
    limiter.enabled = True
    Base.metadata.drop_all(engine)
    engine.dispose()


def register(client: TestClient) -> str:
    response = client.post(
        "/api/v1/auth/register",
        json={"email": "buyer@example.test", "password": "test-password-123"},
    )
    assert response.status_code == 201
    return response.json()["access_token"]


def test_registration_creates_seven_day_trial(client):
    test_client, session_factory = client
    token = register(test_client)
    response = test_client.get("/api/v1/license/me", headers={"Authorization": f"Bearer {token}"})

    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "trial"
    assert body["plan"] == "free"
    assert 6.99 <= (
        datetime.fromisoformat(body["expires_at"].replace("Z", "+00:00"))
        - datetime.fromisoformat(body["starts_at"].replace("Z", "+00:00"))
    ).total_seconds() / 86400 <= 7.01
    with session_factory() as db:
        account = db.scalar(select(models.Account))
        assert account is not None
        assert account.password_hash != "test-password-123"


def test_license_requires_authentication(client):
    test_client, _ = client
    response = test_client.get("/api/v1/license/me")
    assert response.status_code == 401


def test_payment_simulator_never_marks_payment_as_received_or_activates_plan(client):
    test_client, session_factory = client
    token = register(test_client)
    headers = {"Authorization": f"Bearer {token}"}

    response = test_client.post(
        "/api/v1/payments/simulate",
        headers=headers,
        json={"reference": "dev-001", "amount": "5000.00", "currency": "TZS"},
    )
    assert response.status_code == 201
    assert response.json()["status"] == "simulated_not_paid"
    assert "No payment was initiated or received" in response.json()["message"]

    with session_factory() as db:
        payment = db.scalar(select(models.PaymentRecord))
        subscription = db.scalar(select(models.Subscription))
        assert payment is not None and payment.status == "simulated_not_paid"
        assert subscription is not None and subscription.status == "trial"


def test_payment_reference_is_idempotently_rejected(client):
    test_client, _ = client
    token = register(test_client)
    headers = {"Authorization": f"Bearer {token}"}
    payload = {"reference": "same-ref", "amount": "10", "currency": "TZS"}
    assert test_client.post("/api/v1/payments/simulate", headers=headers, json=payload).status_code == 201
    assert test_client.post("/api/v1/payments/simulate", headers=headers, json=payload).status_code == 409


def test_expired_trial_is_reported_as_expired(client):
    test_client, session_factory = client
    token = register(test_client)
    with session_factory() as db:
        trial = db.scalar(select(models.Subscription))
        assert trial is not None
        trial.expires_at = datetime.now(timezone.utc) - timedelta(seconds=1)
        db.commit()

    response = test_client.get("/api/v1/license/me", headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 200
    assert response.json()["status"] == "expired"


def test_invalid_access_token_is_rejected(client):
    test_client, _ = client
    response = test_client.get(
        "/api/v1/license/me",
        headers={"Authorization": "Bearer not-a-real-token"},
    )
    assert response.status_code == 401


@pytest.mark.parametrize("secret", ["", "too-short"])
def test_registration_fails_closed_when_signing_secret_is_missing(client, monkeypatch, secret):
    test_client, session_factory = client
    monkeypatch.setattr(settings, "jwt_secret", secret)

    response = test_client.post(
        "/api/v1/auth/register",
        json={"email": "buyer@example.test", "password": "test-password-123"},
    )
    assert response.status_code == 503
    with session_factory() as db:
        assert db.scalar(select(models.Account)) is None
