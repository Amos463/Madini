from datetime import datetime, timezone
from decimal import Decimal
from uuid import uuid4

from sqlalchemy import DateTime, ForeignKey, Numeric, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .database import Base


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


class Account(Base):
    __tablename__ = "accounts"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    email: Mapped[str] = mapped_column(String(254), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(512))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)
    subscriptions: Mapped[list["Subscription"]] = relationship(back_populates="account")
    payments: Mapped[list["PaymentRecord"]] = relationship(back_populates="account")


class Subscription(Base):
    __tablename__ = "subscriptions"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    account_id: Mapped[str] = mapped_column(ForeignKey("accounts.id"), index=True)
    plan: Mapped[str] = mapped_column(String(16), default="free")
    status: Mapped[str] = mapped_column(String(16), default="trial")
    starts_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    account: Mapped[Account] = relationship(back_populates="subscriptions")


class PaymentRecord(Base):
    __tablename__ = "payment_records"
    __table_args__ = (
        UniqueConstraint("provider", "reference", name="uq_payment_provider_reference"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    account_id: Mapped[str] = mapped_column(ForeignKey("accounts.id"), index=True)
    provider: Mapped[str] = mapped_column(String(40))
    reference: Mapped[str] = mapped_column(String(120))
    amount: Mapped[Decimal] = mapped_column(Numeric(12, 2))
    currency: Mapped[str] = mapped_column(String(3), default="TZS")
    status: Mapped[str] = mapped_column(String(32), default="simulated_not_paid")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)
    account: Mapped[Account] = relationship(back_populates="payments")
