from dataclasses import dataclass
from decimal import Decimal
from typing import Protocol


@dataclass(frozen=True)
class PaymentAttempt:
    provider: str
    reference: str
    amount: Decimal
    currency: str
    status: str
    message: str


class PaymentProvider(Protocol):
    def create_payment(self, reference: str, amount: Decimal, currency: str) -> PaymentAttempt: ...


class DevelopmentPaymentSimulator:
    def create_payment(self, reference: str, amount: Decimal, currency: str) -> PaymentAttempt:
        return PaymentAttempt(
            provider="development-simulator",
            reference=reference,
            amount=amount,
            currency=currency,
            status="simulated_not_paid",
            message="Development simulation only. No payment was initiated or received.",
        )


def get_payment_provider() -> PaymentProvider:
    return DevelopmentPaymentSimulator()
