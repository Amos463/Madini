"""Create minimal account, subscription, and payment tables.

Revision ID: 0001_minimal_backend
Revises:
"""

from alembic import op
import sqlalchemy as sa

revision = "0001_minimal_backend"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "accounts",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("email", sa.String(length=254), nullable=False),
        sa.Column("password_hash", sa.String(length=512), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_accounts_email", "accounts", ["email"], unique=True)

    op.create_table(
        "subscriptions",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("account_id", sa.String(length=36), sa.ForeignKey("accounts.id"), nullable=False),
        sa.Column("plan", sa.String(length=16), nullable=False),
        sa.Column("status", sa.String(length=16), nullable=False),
        sa.Column("starts_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_subscriptions_account_id", "subscriptions", ["account_id"])

    op.create_table(
        "payment_records",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("account_id", sa.String(length=36), sa.ForeignKey("accounts.id"), nullable=False),
        sa.Column("provider", sa.String(length=40), nullable=False),
        sa.Column("reference", sa.String(length=120), nullable=False),
        sa.Column("amount", sa.Numeric(12, 2), nullable=False),
        sa.Column("currency", sa.String(length=3), nullable=False),
        sa.Column("status", sa.String(length=32), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint("provider", "reference", name="uq_payment_provider_reference"),
    )
    op.create_index("ix_payment_records_account_id", "payment_records", ["account_id"])


def downgrade() -> None:
    op.drop_index("ix_payment_records_account_id", table_name="payment_records")
    op.drop_table("payment_records")
    op.drop_index("ix_subscriptions_account_id", table_name="subscriptions")
    op.drop_table("subscriptions")
    op.drop_index("ix_accounts_email", table_name="accounts")
    op.drop_table("accounts")
