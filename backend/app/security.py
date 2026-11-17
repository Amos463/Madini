from datetime import datetime, timedelta, timezone

import jwt
from fastapi import HTTPException, status
from pwdlib import PasswordHash

from .config import settings

password_hash = PasswordHash.recommended()


def ensure_auth_configured() -> None:
    if len(settings.jwt_secret.encode("utf-8")) < 32:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Authentication is not configured safely. Set MADINI_JWT_SECRET to at least 32 bytes.",
        )


def hash_password(password: str) -> str:
    return password_hash.hash(password)


def verify_password(password: str, hashed_password: str) -> bool:
    return password_hash.verify(password, hashed_password)


def create_access_token(account_id: str) -> tuple[str, datetime]:
    ensure_auth_configured()
    now = datetime.now(timezone.utc)
    expires_at = now + timedelta(minutes=settings.access_token_minutes)
    token = jwt.encode(
        {
            "sub": account_id,
            "iss": settings.jwt_issuer,
            "iat": now,
            "exp": expires_at,
        },
        settings.jwt_secret,
        algorithm="HS256",
    )
    return token, expires_at


def decode_access_token(token: str) -> str:
    ensure_auth_configured()
    try:
        payload = jwt.decode(
            token,
            settings.jwt_secret,
            algorithms=["HS256"],
            issuer=settings.jwt_issuer,
            options={"require": ["exp", "iat", "iss", "sub"]},
        )
    except jwt.InvalidTokenError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired access token.",
            headers={"WWW-Authenticate": "Bearer"},
        ) from exc
    account_id = payload.get("sub")
    if not isinstance(account_id, str) or not account_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid access token subject.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return account_id
