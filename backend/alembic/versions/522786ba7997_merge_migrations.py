"""merge migrations

Revision ID: 522786ba7997
Revises: 139261da4f89, 8b4171408110
Create Date: 2026-03-26 01:45:32.945877

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '522786ba7997'
down_revision: Union[str, Sequence[str], None] = ('139261da4f89', '8b4171408110')
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    pass


def downgrade() -> None:
    """Downgrade schema."""
    pass
