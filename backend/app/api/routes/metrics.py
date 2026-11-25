from fastapi import APIRouter, Depends

from app.api.deps import require_capability
from app.models import Capability, Message

router = APIRouter(prefix="/metrics", tags=["metrics"])


@router.get("/", dependencies=[Depends(require_capability(Capability.VIEW_METRICS))])
def read_metrics() -> Message:
    return Message(message="Metrics are not available yet.")
