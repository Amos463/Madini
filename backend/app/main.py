from datetime import datetime, timedelta, timezone
from decimal import Decimal

from fastapi import Depends, FastAPI, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.util import get_remote_address
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from .database import get_db
from .models import Account, PaymentRecord, Subscription
from .payments import get_payment_provider
from .schemas import (
    Credentials,
    LicenseResponse,
    PaymentSimulationRequest,
    PaymentSimulationResponse,
    TokenResponse,
)
from .security import (
    create_access_token,
    decode_access_token,
    ensure_auth_configured,
    hash_password,
    verify_password,
)

limiter = Limiter(key_func=get_remote_address)
app = FastAPI(title="MADINI account and licensing API", version="1.0.0")
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

bearer_scheme = HTTPBearer(auto_error=False)


def current_account(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
    db: Session = Depends(get_db),
) -> Account:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Bearer token required.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    account_id = decode_access_token(credentials.credentials)
    account = db.get(Account, account_id)
    if account is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Account no longer exists.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return account


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/api/v1/auth/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
@limiter.limit("5/minute")
def register(
    request: Request,
    payload: Credentials,
    db: Session = Depends(get_db),
) -> TokenResponse:
    ensure_auth_configured()
    email = payload.email.lower()
    existing = db.scalar(select(Account).where(Account.email == email))
    if existing is not None:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Account already exists.")

    account = Account(email=email, password_hash=hash_password(payload.password))
    now = datetime.now(timezone.utc)
    trial = Subscription(
        account=account,
        plan="free",
        status="trial",
        starts_at=now,
        expires_at=now + timedelta(days=7),
    )
    db.add(account)
    db.add(trial)
    try:
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Account already exists.") from exc

    token, expires_at = create_access_token(account.id)
    return TokenResponse(access_token=token, expires_at=expires_at)


@app.post("/api/v1/auth/login", response_model=TokenResponse)
@limiter.limit("5/minute")
def login(
    request: Request,
    payload: Credentials,
    db: Session = Depends(get_db),
) -> TokenResponse:
    account = db.scalar(select(Account).where(Account.email == payload.email.lower()))
    if account is None or not verify_password(payload.password, account.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    token, expires_at = create_access_token(account.id)
    return TokenResponse(access_token=token, expires_at=expires_at)


@app.get("/api/v1/license/me", response_model=LicenseResponse)
def get_license(account: Account = Depends(current_account), db: Session = Depends(get_db)) -> LicenseResponse:
    subscription = db.scalar(
        select(Subscription)
        .where(Subscription.account_id == account.id)
        .order_by(Subscription.starts_at.desc())
    )
    if subscription is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No license record found.")

    now = datetime.now(timezone.utc)
    expires_at = subscription.expires_at
    if expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=timezone.utc)
    effective_status = subscription.status
    if effective_status in {"trial", "active"} and expires_at <= now:
        effective_status = "expired"
    return LicenseResponse(
        account_id=account.id,
        status=effective_status,
        plan=subscription.plan,
        starts_at=subscription.starts_at,
        expires_at=subscription.expires_at,
        server_time=now,
    )


@app.post(
    "/api/v1/payments/simulate",
    response_model=PaymentSimulationResponse,
    status_code=status.HTTP_201_CREATED,
)
@limiter.limit("10/hour")
def simulate_payment(
    request: Request,
    payload: PaymentSimulationRequest,
    account: Account = Depends(current_account),
    db: Session = Depends(get_db),
) -> PaymentSimulationResponse:
    provider = get_payment_provider()
    attempt = provider.create_payment(payload.reference, payload.amount, payload.currency)
    existing = db.scalar(
        select(PaymentRecord).where(
            PaymentRecord.provider == attempt.provider,
            PaymentRecord.reference == attempt.reference,
        )
    )
    if existing is not None:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Payment reference already exists.")

    payment = PaymentRecord(
        account_id=account.id,
        provider=attempt.provider,
        reference=attempt.reference,
        amount=attempt.amount,
        currency=attempt.currency,
        status=attempt.status,
    )
    db.add(payment)
    db.commit()
    return PaymentSimulationResponse(
        provider="development-simulator",
        status="simulated_not_paid",
        reference=attempt.reference,
        amount=Decimal(attempt.amount),
        currency=attempt.currency,
        message=attempt.message,
    )
