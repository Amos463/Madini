from datetime import datetime
from decimal import Decimal
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class Credentials(BaseModel):
    email: str = Field(min_length=3, max_length=254, pattern=r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
    password: str = Field(min_length=12, max_length=128)


class TokenResponse(BaseModel):
    access_token: str
    token_type: Literal["bearer"] = "bearer"
    expires_at: datetime


class LicenseResponse(BaseModel):
    account_id: str
    status: Literal["trial", "active", "expired"]
    plan: Literal["free", "monthly", "annual"]
    starts_at: datetime
    expires_at: datetime
    server_time: datetime


class PaymentSimulationRequest(BaseModel):
    reference: str = Field(min_length=1, max_length=120, pattern=r"^[A-Za-z0-9._:-]+$")
    amount: Decimal = Field(gt=0, max_digits=12, decimal_places=2)
    currency: Literal["TZS"] = "TZS"


class PaymentSimulationResponse(BaseModel):
    provider: Literal["development-simulator"] = "development-simulator"
    status: Literal["simulated_not_paid"] = "simulated_not_paid"
    reference: str
    amount: Decimal
    currency: str
    message: str


class AccountResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    email: str
    created_at: datetime
