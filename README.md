# MADINI

MADINI is a local-first gold valuation and buying-intelligence application. This repository currently contains a Flutter MVP and a minimal account/licensing API. Do not treat this repository as a production-ready financial valuation system.

## Flutter app

The Flutter app includes a Material 3 interface, English/Kiswahili switching, dark/light themes, a local SQLite assessment store, a basic valuation engine, history, and local search.

```bash
cd /workspaces/Madini
flutter pub get
flutter test
flutter run -d web-server --web-port 3000
```

In the original development environment the Flutter SDK was installed under `/workspaces/flutter`; add that SDK's `bin` to `PATH` if `flutter` is not found.

## Backend API

The backend stores account credentials (password hashes only), trial/subscription metadata, and payment references. It has no endpoint or model for ore assessments, samples, assay data, costs, or reports. It includes email/password registration and login, signed short-lived bearer tokens, authenticated license lookup, request rate limits, and a payment-provider interface with a development-only simulator.

The simulator always reports `simulated_not_paid`; it does not initiate a payment or grant/extend a subscription. A real payment provider and verified webhook flow are not implemented.

### Local setup

Python 3.11+ is recommended. From the repository root:

```bash
cd backend
python -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
cp .env.example .env
```

Set a unique secret in `backend/.env` before using authentication:

```text
MADINI_JWT_SECRET=<a-random-secret-of-at-least-32-bytes>
```

The development default database is SQLite. For deployment, configure `MADINI_DATABASE_URL` with a PostgreSQL connection URL, configure a strong JWT secret through the environment/secret manager, and terminate TLS at a trusted HTTPS proxy. Apply schema migrations and start the API:

```bash
alembic upgrade head
uvicorn app.main:app --host 127.0.0.1 --port 8000
pytest
```

### Current API endpoints

- `POST /api/v1/auth/register` — create an account and seven-day trial
- `POST /api/v1/auth/login` — obtain a short-lived access token
- `GET /api/v1/license/me` — authenticated current license state
- `POST /api/v1/payments/simulate` — authenticated development simulation only
- `GET /health` — process health check

## Known limitations

- Android APK build requires an Android SDK; one was not available in the original environment.
- The Flutter SQLite database and file-copy backup are not encrypted; do not store sensitive business data in this MVP. Encrypted database-at-rest storage and user-selected encrypted backup/restore are not implemented.
- The Flutter UI does not yet call this backend or securely store API tokens.
- Subscription renewal/payment verification, real payment provider integration, account recovery, email verification, and license offline-signing/clock-tamper policy are not implemented.
- PDFs, OCR, certificate attachment, statistical sample comparison, and full database import/restore remain incomplete.
- The gold-price entry is manual; no live feed is configured. Recovery, assay, and field values remain user-supplied assumptions, not verified outcomes.
- The current valuation code needs further financial review, decimal-safe currency arithmetic, and broader formula/edge-case tests before commercial use.
