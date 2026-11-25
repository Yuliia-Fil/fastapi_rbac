"""Add user roles and preserve existing privileges.

Revision ID: aa8de69f2b13
Revises: fe56fa70289e
"""

import sqlalchemy as sa
from alembic import op

revision = "aa8de69f2b13"
down_revision = "fe56fa70289e"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "user", sa.Column("role", sa.String(7), server_default="member", nullable=False)
    )
    op.execute("""UPDATE "user" SET role = 'admin' WHERE is_superuser""")
    op.create_check_constraint(
        "ck_user_role", "user", "role IN ('admin', 'manager', 'member')"
    )
    op.drop_column("user", "is_superuser")


def downgrade() -> None:
    op.add_column(
        "user",
        sa.Column("is_superuser", sa.Boolean(), server_default=sa.false(), nullable=False),
    )
    op.execute("""UPDATE "user" SET is_superuser = (role = 'admin')""")
    op.alter_column("user", "is_superuser", server_default=None)
    op.drop_constraint("ck_user_role", "user", type_="check")
    op.drop_column("user", "role")
